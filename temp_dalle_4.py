import requests
import json
import urllib.request
import os

api_key = "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"
prompt = """A friendly robot sitting at a computer, programming in a modern office environment, digital art style"""
output_path = "./generated/resources/test-dalle_image_4.png"

# Запрос к OpenAI DALL-E API
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

data = {
    "model": "dall-e-3",
    "prompt": prompt,
    "n": 1,
    "size": "1024x1024",
    "quality": "standard",
    "style": "natural"
}

try:
    response = requests.post(
        "https://api.openai.com/v1/images/generations",
        headers=headers,
        json=data
    )
    response.raise_for_status()

    result = response.json()
    image_url = result["data"][0]["url"]

    # Скачиваем изображение
    urllib.request.urlretrieve(image_url, output_path)
    print(f"Изображение сохранено: {output_path}")

except Exception as e:
    print(f"Ошибка при генерации изображения: {e}")
    exit(1)
