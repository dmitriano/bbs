#!/usr/bin/env python3
"""
Windows screen OCR alert (v2)

Скрипт снимает экран по таймеру и проигрывает звуковой сигнал, если на экране
появляется указанный текст. Добавлены настройки OCR (язык, PSM/OEM),
предобработка изображения, порог уверенности и «N подряд попаданий» для
снижения ложных срабатываний.

Требования:
  - Python 3.8+
  - pip install mss pillow pytesseract
  - Установить Tesseract OCR (Windows): https://github.com/UB-Mannheim/tesseract/wiki
    (путь по умолчанию: C:\Program Files\Tesseract-OCR\tesseract.exe)

Примеры:
  python windows-screen-ocr-alert.py --text "ошибка" --lang rus --interval 2
  python windows-screen-ocr-alert.py --text "BUILD FAILED" --lang eng --psm 6 --scale 2.0 --binarize
  python windows-screen-ocr-alert.py --text "PowerShellasdfasdfasdf" --region 200,100,1000,400 --min_conf 70 --need_hits 2

Опции:
  --text          : текст для поиска (обязательный)
  --interval      : интервал в секундах между сканами (по умолчанию 2)
  --region        : область экрана left,top,width,height (по умолчанию весь экран)
  --case          : учёт регистра (default: false)
  --lang          : язык(и) Tesseract, например eng, rus, eng+rus (default: eng)
  --psm           : Page Segmentation Mode (по умолчанию 6: Assume a single uniform block of text)
  --oem           : OCR Engine Mode (по умолчанию 3: Default/LSTM only в новых версиях)
  --scale         : масштабировать изображение (float, default: 1.5)
  --binarize      : применить бинаризацию (порог 180) после серого
  --invert        : инвертировать после бинаризации (полезно для светлого текста на тёмном фоне)
  --sharpen       : лёгкая резкость
  --contrast      : усилить контраст (коэффициент, по умолчанию 1.0 — без изменений)
  --tesseract_path: путь к tesseract.exe (если не в PATH)
  --min_conf      : минимальная уверенность слова (0..100) для учёта совпадений (default: 60)
  --need_hits     : сколько подряд срабатываний нужно перед сигналом (default: 1)
  --beep_freq     : частота сигнала (Гц, default: 1000)
  --beep_dur      : длительность сигнала (мс, default: 500)

Советы по качеству OCR:
  - ограничьте область (--region) до конкретного окна/панели;
  - увеличьте масштаб (--scale 1.5..3.0) и используйте --psm 6 для строк/абзацев;
  - задайте правильные языки (--lang eng, rus или eng+rus);
  - примените --binarize и при необходимости --invert для тёмных тем.
"""

#!/usr/bin/env python3
"""
Windows screen OCR alert (v2.4)

Изменения:
- NEW: параметр --sound_path <wav>, чтобы проигрывать собственный звуковой файл вместо Beep.
- По умолчанию остаётся winsound.Beep; при ошибке воспроизведения файла — автоматический фолбэк на Beep/MessageBeep.
- Интервал по умолчанию 100 мс.
"""

import argparse
import time
import sys
import os
from typing import Optional, Tuple

try:
    import mss
    from PIL import Image, ImageFilter, ImageEnhance
    import pytesseract
except Exception as e:
    print("Требуются библиотеки mss, pillow, pytesseract. Установите их: pip install mss pillow pytesseract")
    raise

if os.name != 'nt':
    print("Предупреждение: скрипт рассчитан на Windows (winsound).")

try:
    import winsound
    HAVE_WINSOUND = True
except Exception:
    HAVE_WINSOUND = False


def normalize_path(p: Optional[str]) -> Optional[str]:
    if not p:
        return p
    return p.replace('\\', '/')


def parse_region(s: str) -> Optional[Tuple[int,int,int,int]]:
    try:
        parts = [int(p) for p in s.split(',')]
        if len(parts) != 4:
            raise ValueError()
        return tuple(parts)
    except Exception:
        raise argparse.ArgumentTypeError("region must be left,top,width,height")


def screenshot_region(region: Optional[Tuple[int,int,int,int]] = None):
    with mss.mss() as sct:
        if region:
            left, top, width, height = region
            monitor = {"left": left, "top": top, "width": width, "height": height}
        else:
            monitor = sct.monitors[0]
        sct_img = sct.grab(monitor)
        from PIL import Image
        img = Image.frombytes('RGB', sct_img.size, sct_img.rgb)
        return img


def preprocess(img, scale: float, do_binarize: bool, invert: bool, sharpen: bool, contrast: float):
    from PIL import Image, ImageFilter, ImageEnhance
    im = img.convert('L')
    if scale and abs(scale - 1.0) > 1e-3:
        w, h = im.size
        im = im.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
    if contrast and abs(contrast - 1.0) > 1e-3:
        im = ImageEnhance.Contrast(im).enhance(contrast)
    if do_binarize:
        im = im.point(lambda p: 255 if p > 180 else 0)
    if invert:
        im = im.point(lambda p: 255 - p)
    if sharpen:
        im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=150, threshold=3))
    return im


def tesseract_text_and_conf(img, lang: str, psm: int, oem: int):
    config = f"--psm {psm} --oem {oem}"
    data = pytesseract.image_to_data(img, lang=lang, config=config, output_type=pytesseract.Output.DICT)
    words = []
    for txt, conf in zip(data.get('text', []), data.get('conf', [])):
        try:
            c = int(conf)
        except Exception:
            c = -1
        if txt and txt.strip():
            words.append((txt, c))
    full_text = " ".join(w for w, _ in words)
    return full_text, words


def play_alert(sound_path: Optional[str], freq: int = 1000, dur_ms: int = 500):
    """Проигрывает пользовательский WAV, иначе Beep/MessageBeep."""
    if not HAVE_WINSOUND:
        print("[BEEP]", flush=True)
        return
    try:
        if sound_path:
            p = normalize_path(sound_path)
            if os.path.isfile(p) and p.lower().endswith('.wav'):
                winsound.PlaySound(p, winsound.SND_FILENAME | winsound.SND_ASYNC)
                return
            else:
                print(f"[sound] Файл не найден или не WAV: {p}. Фолбэк на Beep.")
        winsound.Beep(freq, dur_ms)
    except Exception as e:
        print(f"[sound] Ошибка воспроизведения: {e}. Фолбэк на MessageBeep.")
        try:
            winsound.MessageBeep()
        except Exception:
            print("[sound] Не удалось проиграть системный звук.")


def main():
    parser = argparse.ArgumentParser(description='Screen OCR alert for Windows (v2.4)')
    parser.add_argument('--text', required=True, help='Search text (utf-8)')
    parser.add_argument('--interval', type=int, default=100, help='Interval between scans in milliseconds (default=100)')
    parser.add_argument('--region', type=parse_region, default=None, help='left,top,width,height')
    parser.add_argument('--case', action='store_true', help='Case-sensitive search')
    parser.add_argument('--lang', default='eng', help='Tesseract languages, e.g., eng, rus, eng+rus')
    parser.add_argument('--psm', type=int, default=6, help='Tesseract PSM (default 6)')
    parser.add_argument('--oem', type=int, default=3, help='Tesseract OEM (default 3)')
    parser.add_argument('--scale', type=float, default=1.5, help='Resize factor before OCR')
    parser.add_argument('--binarize', action='store_true', help='Apply thresholding')
    parser.add_argument('--invert', action='store_true', help='Invert after thresholding')
    parser.add_argument('--sharpen', action='store_true', help='Apply unsharp mask')
    parser.add_argument('--contrast', type=float, default=1.0, help='Increase contrast (1.0 = off)')
    parser.add_argument('--tesseract_path', default=None, help='Path to tesseract.exe')
    parser.add_argument('--min_conf', type=int, default=60, help='Minimal word confidence to consider (0..100)')
    parser.add_argument('--need_hits', type=int, default=1, help='How many consecutive detections to beep')
    parser.add_argument('--beep_freq', type=int, default=1000, help='Beep frequency Hz')
    parser.add_argument('--beep_dur', type=int, default=500, help='Beep duration ms')
    parser.add_argument('--sound_path', default=None, help='Path to custom WAV file to play on alert')

    args = parser.parse_args()

    if args.tesseract_path:
        fixed_path = normalize_path(args.tesseract_path)
        pytesseract.pytesseract.tesseract_cmd = fixed_path

    interval_sec = args.interval / 1000.0

    search_text = args.text if args.case else args.text.lower()
    hits_in_row = 0

    print(f"Search text: {args.text}")
    print(f"Интервал сканирования: {args.interval} мс")
    if args.sound_path:
        print(f"Звук оповещения: {normalize_path(args.sound_path)}")
    print("Начинаю мониторить экран. Нажмите Ctrl+C для выхода.")

    try:
        while True:
            img = screenshot_region(args.region)
            proc = preprocess(img, args.scale, args.binarize, args.invert, args.sharpen, args.contrast)
            full_text, words = tesseract_text_and_conf(proc, args.lang, args.psm, args.oem)

            cmp_text = full_text if args.case else full_text.lower()

            matched = search_text in cmp_text

            avg_conf = None
            if matched:
                tokens = [t for t in search_text.split() if t]
                confs = []
                for t, c in words:
                    tt = t if args.case else t.lower()
                    if any(tok in tt for tok in tokens):
                        if c >= 0:
                            confs.append(c)
                if confs:
                    avg_conf = sum(confs)/len(confs)
                    if avg_conf < args.min_conf:
                        matched = False

            if matched:
                hits_in_row += 1
                if avg_conf is not None:
                    print(f"Hit {hits_in_row} (avg_conf≈{avg_conf:.0f}) at {time.strftime('%Y-%m-%d %H:%M:%S')}")
                else:
                    print(f"Hit {hits_in_row} at {time.strftime('%Y-%m-%d %H:%M:%S')}")
                if hits_in_row >= args.need_hits:
                    play_alert(args.sound_path, args.beep_freq, args.beep_dur)
                    hits_in_row = 0
            else:
                hits_in_row = 0

            time.sleep(interval_sec)
    except KeyboardInterrupt:
        print('\nЗавершение.')
        sys.exit(0)


if __name__ == '__main__':
    main()