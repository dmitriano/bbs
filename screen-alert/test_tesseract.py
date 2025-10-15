from PIL import Image, ImageDraw, ImageFont
import pytesseract

# если Tesseract не в PATH, раскомментируйте и укажите путь:
pytesseract.pytesseract.tesseract_cmd = r"C:\\Program Files\\Tesseract-OCR\\tesseract.exe"

# создаём тестовое изображение с текстом
img = Image.new("RGB", (500, 300), color=(255, 255, 255))
draw = ImageDraw.Draw(img)
draw.text((10, 40), "Hello world!", fill=(0, 0, 0))

# распознаём текст
text = pytesseract.image_to_string(img, lang="eng")  # можно lang="eng" для английского
print("Распознанный текст:", text.strip())
