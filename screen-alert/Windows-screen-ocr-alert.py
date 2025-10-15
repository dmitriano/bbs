#!/usr/bin/env python3
"""
Windows screen OCR alert

Скрипт снимает экран по таймеру и проигрывает звуковой сигнал, если на экране
появляется указанный текст.

Требования:
  - Python 3.8+
  - pip install mss pillow pytesseract
  - Установить Tesseract OCR (https://github.com/tesseract-ocr/tesseract). Для Windows
    обычно: C:\Program Files\Tesseract-OCR\tesseract.exe

Запуск:
  python windows-screen-ocr-alert.py --text "ошибка" --interval 2

Опции:
  --text      : текст для поиска (обязательный)
  --interval  : интервал в секундах между сканами (по умолчанию 2)
  --region    : область экрана в формате left,top,width,height (по умолчанию весь экран)
  --case      : учёт регистра (default: false)
  --beep_freq : частота сигнала в герцах (default: 1000)
  --beep_dur  : длительность сигнала в мс (default: 500)

"""

import argparse
import time
import sys
import os
from typing import Optional, Tuple

try:
    import mss
    from PIL import Image
    import pytesseract
except Exception as e:
    print("Требуются библиотеки mss, pillow, pytesseract. Установите их: pip install mss pillow pytesseract")
    raise

# winsound доступен только на Windows
if os.name != 'nt':
    print("Этот скрипт предназначен для Windows (winsound).")

import winsound


def parse_region(s: str) -> Optional[Tuple[int,int,int,int]]:
    try:
        parts = [int(p) for p in s.split(',')]
        if len(parts) != 4:
            raise ValueError()
        return tuple(parts)
    except Exception:
        raise argparse.ArgumentTypeError("region must be left,top,width,height")


def screenshot_region(region: Optional[Tuple[int,int,int,int]] = None) -> Image.Image:
    """Сделать скриншот региона (left, top, width, height) или всего экрана."""
    with mss.mss() as sct:
        if region:
            left, top, width, height = region
            monitor = {"left": left, "top": top, "width": width, "height": height}
        else:
            monitor = sct.monitors[0]  # весь виртуальный экран
        sct_img = sct.grab(monitor)
        img = Image.frombytes('RGB', sct_img.size, sct_img.rgb)
        return img


def ocr_image(img: Image.Image) -> str:
    # можно добавить предобработку: серый, порог, увеличение
    gray = img.convert('L')
    # увеличить для более надёжного распознавания
    w, h = gray.size
    scale = 1.5 if max(w, h) < 2000 else 1.0
    if scale != 1.0:
        gray = gray.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
    text = pytesseract.image_to_string(gray)
    return text


def alert_beep(freq: int = 1000, dur_ms: int = 500):
    try:
        winsound.Beep(freq, dur_ms)
    except RuntimeError:
        # если Beep не сработал — воспроизвести системный звук
        winsound.MessageBeep()


def main():
    parser = argparse.ArgumentParser(description='Screen OCR alert for Windows')
    parser.add_argument('--text', required=True, help='Search text (encoding: utf-8)')
    parser.add_argument('--interval', type=float, default=2.0, help='Seconds between scans')
    parser.add_argument('--region', type=parse_region, default=None, help='left,top,width,height')
    parser.add_argument('--case', action='store_true', help='Case-sensitive search')
    parser.add_argument('--beep_freq', type=int, default=1000, help='Beep frequency Hz')
    parser.add_argument('--beep_dur', type=int, default=500, help='Beep duration ms')
    parser.add_argument('--tesseract_path', default=None, help='Optional path to tesseract.exe')

    args = parser.parse_args()

    if args.tesseract_path:
        pytesseract.pytesseract.tesseract_cmd = args.tesseract_path

    search_text = args.text
    print(f"Search text: {search_text}")
    if not args.case:
        search_text = search_text.lower()

    try:
        print("Начинаю мониторить экран. Нажмите Ctrl+C для выхода.")
        while True:
            img = screenshot_region(args.region)
            recognized = ocr_image(img)
            cmp_text = recognized if args.case else recognized.lower()
            if search_text in cmp_text:
                print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - Найден текст!\n---\n{recognized}\n---")
                # сигнал и пауза, чтобы не спамить
                alert_beep(args.beep_freq, args.beep_dur)
                # подождать несколько интервалов, чтобы не сработать по одному кадру несколько раз
                time.sleep(max(1.0, args.interval))
            else:
                # debug: можно раскомментировать для вывода распознанного текста
                # print('.', end='', flush=True)
                pass
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print('\nЗавершение.')
        sys.exit(0)


if __name__ == '__main__':
    main()
