#include <torch/torch.h>
#include <algorithm>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>
#include <string>
#include <cmath>

struct Candle { long long ts; double o, h, l, c; };

std::vector<Candle> read_csv(const std::string& path) {
    std::ifstream f(path);
    if (!f) throw std::runtime_error("open: " + path);
    std::vector<Candle> v;
    std::string line;

    // пробуем пропустить заголовок
    if (std::getline(f, line)) {
        if (!line.empty() && std::isdigit(line[0])) {
            std::stringstream ss(line);
            std::string s; std::vector<std::string> cols;
            while (std::getline(ss, s, ',')) cols.push_back(s);
            if (cols.size() >= 5)
                v.push_back({ std::stoll(cols[0]), std::stod(cols[1]), std::stod(cols[2]),
                             std::stod(cols[3]), std::stod(cols[4]) });
        }
    }
    while (std::getline(f, line)) {
        if (line.empty()) continue;
        std::stringstream ss(line);
        std::string s; std::vector<std::string> cols;
        while (std::getline(ss, s, ',')) cols.push_back(s);
        if (cols.size() < 5) continue;
        v.push_back({ std::stoll(cols[0]), std::stod(cols[1]), std::stod(cols[2]),
                     std::stod(cols[3]), std::stod(cols[4]) });
    }
    return v;
}

struct Args {
    int W = 64;               // длина окна
    int H = 12;               // горизонт прогноза
    double up_thresh = 0.002; // порог "роста"
    int hidden = 64;          // скрытый размер LSTM
    int layers = 1;
    int epochs = 8;
    int batch = 64;
    double lr = 1e-3;
    double wd = 1e-4;

    int train_start = 500, train_end = 2500;
    int test_start = 2500, test_end = 3600;

    float p_buy = 0.6f;       // BUY если вероятность роста >= 0.6
    float p_sell = 0.45f;     // SELL если вероятность <= 0.45
    double tp = 0.015;        // take profit
    double sl = 0.008;        // stop loss
};

// простейший парсер аргументов
Args parse_args(int argc, char** argv) {
    Args a;
    for (int i = 2; i < argc; i++) {
        std::string s = argv[i];
        auto nexti = [&]() { return std::stoi(argv[++i]); };
        auto nextd = [&]() { return std::stod(argv[++i]); };
        if (s == "--train-start") a.train_start = nexti();
        else if (s == "--train-end") a.train_end = nexti();
        else if (s == "--test-start") a.test_start = nexti();
        else if (s == "--test-end") a.test_end = nexti();
        else if (s == "--W") a.W = nexti();
        else if (s == "--H") a.H = nexti();
        else if (s == "--hidden") a.hidden = nexti();
        else if (s == "--epochs") a.epochs = nexti();
    }
    return a;
}

// формирование обучающего набора
struct Sample { torch::Tensor x, y; };

std::vector<Sample> make_dataset(const std::vector<Candle>& k, int start, int end, int W, int H, double up_thresh) {
    std::vector<Sample> ds;
    start = std::max(start, W);
    end = std::min(end, (int)k.size() - H);
    for (int i = start; i < end; ++i) {
        std::vector<double> win;
        for (int j = i - W; j < i; ++j) win.push_back(k[j].c);
        // нормализация
        double m = 0, s = 0; for (double v : win) m += v; m /= W;
        for (double v : win) s += (v - m) * (v - m);
        s = std::sqrt(s / W) + 1e-12;
        for (double& v : win) v = (v - m) / s;
        auto x = torch::from_blob(win.data(), { W,1 }, torch::kDouble).clone().to(torch::kFloat32);
        double ret = k[i + H].c / k[i].c - 1.0;
        float y = (ret >= up_thresh) ? 1.f : 0.f;
        ds.push_back({ x, torch::tensor({y}, torch::kFloat32) });
    }
    return ds;
}

class SeqDataset : public torch::data::datasets::Dataset<SeqDataset> {
    std::vector<Sample> data_;
public:
    explicit SeqDataset(std::vector<Sample> d) : data_(std::move(d)) {}
    torch::data::Example<> get(size_t idx) override {
        return { data_[idx].x, data_[idx].y };
    }
    torch::optional<size_t> size() const override { return data_.size(); }
};

// Модель BiLSTM
struct BiLSTMImpl : torch::nn::Module {
    torch::nn::LSTM lstm{ nullptr };
    torch::nn::Linear head{ nullptr };

    BiLSTMImpl(int input_size, int hidden, int layers) {
        torch::nn::LSTMOptions opts(input_size, hidden);
        opts.batch_first(true);
        opts.bidirectional(true);
        opts.num_layers(layers);   // ✅ правильное имя поля

        lstm = torch::nn::LSTM(opts);
        head = torch::nn::Linear(hidden * 2, 1);
        register_module("lstm", lstm);
        register_module("head", head);
    }

    torch::Tensor forward(torch::Tensor x) {
        auto out = std::get<0>(lstm->forward(x));  // [B,T,2H]
        auto last = out.select(1, out.size(1) - 1);  // [B,2H]
        return head->forward(last);                // [B,1]
    }
};
TORCH_MODULE(BiLSTM);

struct Trade { int entry_i = -1, exit_i = -1; double entry_px = 0, exit_px = 0; std::string reason; };

int main(int argc, char** argv) {
    if (argc < 2) { std::cerr << "Usage: " << argv[0] << " ohlc.csv [options]\n"; return 1; }

    auto candles = read_csv(argv[1]);
    Args a = parse_args(argc, argv);

    auto train = make_dataset(candles, a.train_start, a.train_end, a.W, a.H, a.up_thresh);
    auto test = make_dataset(candles, a.test_start, a.test_end, a.W, a.H, a.up_thresh);

    SeqDataset train_ds(train), test_ds(test);
    auto train_loader = torch::data::make_data_loader(train_ds.map(torch::data::transforms::Stack<>()), a.batch);
    auto test_loader = torch::data::make_data_loader(test_ds.map(torch::data::transforms::Stack<>()), a.batch);

    BiLSTM net(1, a.hidden, a.layers);
    net->to(torch::kFloat32);

    torch::optim::AdamW opt(net->parameters(), torch::optim::AdamWOptions(a.lr).weight_decay(a.wd));

    // -------- обучение --------
    for (int e = 1; e <= a.epochs; ++e) {
        net->train();
        double loss_sum = 0; int n = 0;
        for (auto& batch : *train_loader) {
            auto x = batch.data.to(torch::kFloat32);
            auto y = batch.target.to(torch::kFloat32);
            opt.zero_grad();
            auto logit = net->forward(x);
            auto loss = torch::binary_cross_entropy_with_logits(logit, y);
            loss.backward();
            opt.step();
            loss_sum += loss.item<double>(); ++n;
        }
        std::cout << "Epoch " << e << " loss=" << (loss_sum / std::max(1, n)) << "\n";
    }

    // -------- инференс и сигналы --------
    net->eval();
    std::vector<float> probs;
    for (auto& batch : *test_loader) {
        auto x = batch.data.to(torch::kFloat32);
        auto p = torch::sigmoid(net->forward(x)).to(torch::kCPU).squeeze(1);
        for (int i = 0; i < p.size(0); ++i) probs.push_back(p[i].item<float>());
    }

    std::vector<int> idx;
    for (int i = a.test_start; i < std::min(a.test_end, (int)candles.size() - a.H); ++i)
        idx.push_back(i);

    bool in_pos = false;
    Trade tr;
    std::vector<Trade> done;

    for (size_t k = 0; k < probs.size(); ++k) {
        int i = idx[k];
        double px = candles[i].c;
        float p = probs[k];

        if (!in_pos) {
            if (p >= a.p_buy) {
                in_pos = true;
                tr.entry_i = i; tr.entry_px = px; tr.reason = "buy";
            }
        }
        else {
            bool tp = px >= tr.entry_px * (1 + a.tp);
            bool sl = px <= tr.entry_px * (1 - a.sl);
            bool down = p <= a.p_sell;
            if (tp || sl || down) {
                tr.exit_i = i; tr.exit_px = px;
                tr.reason += tp ? "|tp" : sl ? "|sl" : "|p_down";
                done.push_back(tr);
                in_pos = false; tr = Trade{};
            }
        }
    }
    if (in_pos) { tr.exit_i = a.test_end - 1; tr.exit_px = candles[tr.exit_i].c; tr.reason += "|eod"; done.push_back(tr); }

    // -------- отчёт --------
    std::cout << "\nSignals:\n";
    double pnl = 0; int win = 0;
    for (auto& t : done) {
        double r = t.exit_px / t.entry_px - 1.0;
        pnl += r; if (r > 0) win++;
        std::cout << "BUY @" << t.entry_i << " (" << t.entry_px << ")  SELL @" << t.exit_i
            << " (" << t.exit_px << ")  ret=" << r * 100 << "%  " << t.reason << "\n";
    }
    std::cout << "Total PnL=" << pnl * 100 << "%  winrate=" << (done.empty() ? 0 : win * 100.0 / done.size()) << "%\n";
}
