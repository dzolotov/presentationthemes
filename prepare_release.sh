#!/bin/bash

# prepare_release.sh - Скрипт для подготовки релиза презентации
# Создает структуру курса, генерирует артефакты и изображения

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Подготовка релиза презентации${NC}"

# Проверяем аргументы
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Использование: $0 <файл.md>${NC}"
    echo "   Пример: $0 lecture2.md"
    exit 1
fi

INPUT_FILE="$1"

# Проверяем существование файла
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}❌ Файл $INPUT_FILE не найден в текущем каталоге${NC}"
    exit 1
fi

CURRENT_DIR=$(pwd)
FILENAME=$(basename "$INPUT_FILE" .md)

echo -e "${BLUE}📋 Входной файл: $INPUT_FILE${NC}"
echo -e "${BLUE}📁 Текущий каталог: $CURRENT_DIR${NC}"

# Запрашиваем параметры курса
echo ""
echo -e "${YELLOW}📝 Введите параметры курса:${NC}"
read -p "Название курса (например, 'Kubernetes Advanced'): " COURSE_NAME
read -p "Поток курса (например, '2024-11'): " FLOW
read -p "Номер лекции (например, '02'): " LECTURE_NUMBER
read -p "Тема лекции краткая (например, 'StatefulSet и Storage'): " TOPIC
read -p "Полное название урока (например, 'Введение в Kubernetes: Хранение данных, Helm'): " LESSON_TITLE

# Запрашиваем информацию о следующем вебинаре
echo ""
echo -e "${YELLOW}📅 Информация о следующем вебинаре:${NC}"
read -p "Дата следующего вебинара (например, '15.12.2024'): " NEXT_DATE
read -p "Тема следующего вебинара (например, 'Мониторинг и логирование'): " NEXT_TOPIC

# Запрашиваем номер активного модуля для карты курса
echo ""
echo -e "${YELLOW}📚 Карта курса:${NC}"
read -p "Номер активного модуля (например, '2'): " ACTIVE_MODULE

# Проверяем, есть ли уже фон для карты знаний
BACKGROUND_PROMPT=""
if [ -f "resources/knowledge_map_bg.png" ]; then
    echo ""
    echo -e "${GREEN}✅ Найден существующий фон карты знаний: resources/knowledge_map_bg.png${NC}"
    echo -e "${BLUE}   Пропускаем генерацию нового фона${NC}"
else
    # Запрашиваем промпт для фона карты знаний
    echo ""
    echo -e "${YELLOW}🎨 Настройка фона карты знаний:${NC}"
    echo "Введите промпт для генерации фона (на английском, например 'kubernetes cluster abstract background')."
    echo "Для завершения ввода введите строку содержащую только '---' и нажмите Enter:"
    while read -r line; do
        if [ "$line" = "---" ]; then
            break
        fi
        if [ -n "$BACKGROUND_PROMPT" ]; then
            BACKGROUND_PROMPT="$BACKGROUND_PROMPT $line"
        else
            BACKGROUND_PROMPT="$line"
        fi
    done
fi

# Создаем структуру каталогов
OBSIDIAN_BASE="$HOME/Obsidian/MySecureNotes"
COURSE_DIR="$OBSIDIAN_BASE/Knowledge/Courses/Presentations/$COURSE_NAME/$FLOW/${LECTURE_NUMBER}-${TOPIC// /-}"
THEMES_DIR="$OBSIDIAN_BASE/.themes"
META_FILE="$OBSIDIAN_BASE/Knowledge/Courses/Presentations/$COURSE_NAME/meta"

echo ""
echo -e "${BLUE}📁 Создаем структуру каталогов${NC}"
mkdir -p "$COURSE_DIR/resources"
mkdir -p "$COURSE_DIR/generated"

# Создаем файл презентации в формате шаблона [S] с титульным листом и завершающими слайдами
LECTURE_FILE="$COURSE_DIR/${TOPIC// /-}.md"

echo -e "${BLUE}📝 Создаем полную презентацию с титульным листом и завершающими слайдами${NC}"

# Функция создания карты курса
create_course_map() {
    if [ -f "$META_FILE" ]; then
        echo "<ul>"
        echo "<li class=\"start\"></li>"

        # Читаем coursemap из meta файла
        local in_coursemap=false
        local index=1

        while IFS= read -r line; do
            if [[ "$line" == "coursemap:"* ]]; then
                in_coursemap=true
                continue
            fi

            if [[ "$in_coursemap" == true ]]; then
                if [[ "$line" =~ ^[[:space:]]*- ]]; then
                    # Извлекаем название модуля
                    module_name=$(echo "$line" | sed 's/^[[:space:]]*- //')

                    if [ "$index" == "$ACTIVE_MODULE" ]; then
                        echo "<li class=\"active\">$index. $module_name</li>"
                    else
                        echo "<li>$index. $module_name</li>"
                    fi

                    index=$((index + 1))
                elif [[ "$line" =~ ^[[:space:]]*[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                    # Если встретили новое поле YAML, выходим из coursemap
                    break
                fi
            fi
        done < "$META_FILE"

        echo "<li class=\"finish\"></li>"
        echo "</ul>"
    else
        echo "<ul>"
        echo "<li class=\"start\"></li>"
        echo "<li class=\"active\">$ACTIVE_MODULE. $TOPIC</li>"
        echo "<li class=\"finish\"></li>"
        echo "</ul>"
    fi
}

# Функция создания титульного листа
create_title_slide() {
    cat << EOF
---
marp: true
theme: otusnew-extended
paginate: false
---

<!-- _class: first_page -->

###

# $LESSON_TITLE

<hr>

## $COURSE_NAME

---

<!-- _class: second_page -->

# REC

## Проверить, идет ли запись

### Меня хорошо видно<br/>& слышно?

####

#####

---

<!-- _class: third_page -->

<img class="additional-image" src="https://raw.githubusercontent.com/dzolotov/otus/refs/heads/main/theme/image18.jpg"/>

<div class="avatar">
  <img src="https://raw.githubusercontent.com/dzolotov/otus/refs/heads/main/theme/dzolotov.png" alt="Avatar Image" class="avatar-image">
</div>

# Дмитрий Золотов

## Flutter Dev @Yandex, FullStack Dev, DevOps

- проводил курсы подготовки к экзамену LPIC (101/102, 201/202, 301/302)
- DevOps c 2012 года, Linux-administrator с 2000 года
- сейчас - разработчик мобильных приложений в Yandex Pro (Доставка)
- Telegram: @dmitriizolotov

---
<!-- _class: page_rules -->

# Правила вебинара

### Активно<br/>участвуем

#### Off-topic обсуждаем<br/>в учебной группе <span class="group-id">#$COURSE_NAME</span>

##### Задаем вопрос<br/>в чат или голосом

###### Вопросы вижу в чате,<br/>могу ответить не сразу

---
<!-- _class: course_page -->

# Карта курса

<h1>Карта курса</h1>

$(create_course_map)

---

EOF
}

# Функция создания завершающих слайдов
create_final_slides() {
    cat << EOF

---
<!-- _class: page_section -->

<hr/>

# Заполните, пожалуйста, опрос о занятии

## Мы читаем все ваши сообщения<br/>и берем их в работу ✏️❤️

---
<!-- _class: page_final -->

# Приглашаем на следующий вебинар: $NEXT_DATE $NEXT_TOPIC

#### Ссылка на вебинар будет в ЛК за 15 минут

##### Материалы к занятию в ЛК — можно изучать

###### Обязательный материал обозначен красной лентой

EOF
}

# Проверяем, есть ли уже правильная структура шаблона [S]
HAS_FRONT_MATTER=$(head -5 "$INPUT_FILE" | grep -c "marp: true" || true)
ROUTE_START=$(grep -n "page_route\|Маршрут занятия" "$INPUT_FILE" | head -1 | cut -d: -f1 || true)

# Создаем полную презентацию
if [ "$HAS_FRONT_MATTER" -gt 0 ] && [ -n "$ROUTE_START" ]; then
    echo -e "${BLUE}📄 Файл содержит структуру шаблона [S], создаем полную версию${NC}"

    # Титульный лист
    create_title_slide > "$LECTURE_FILE"

    # Основной контент (исключаем front matter и служебные слайды)
    cat "$INPUT_FILE" | \
        sed '1,/^---$/d' | \
        sed '/<!-- _class: first_page/,/^---$/d' | \
        sed '/<!-- _class: second_page/,/^---$/d' | \
        sed '/<!-- _class: third_page/,/^---$/d' | \
        sed '/<!-- _class: course_page/,/^---$/d' | \
        sed '/<!-- _class: page_rules/,/^---$/d' | \
        sed '/<!-- _class: page_final/,$d' | \
        sed '/# Заполните.*опрос/,$d' | \
        sed '/# Приглашаем на следующий/,$d' >> "$LECTURE_FILE"

    # Завершающие слайды
    create_final_slides >> "$LECTURE_FILE"

    # Очищаем пустые слайды (слайды только с hr без контента)
    python3 -c "
import re
with open('$LECTURE_FILE', 'r') as f:
    content = f.read()

# Удаляем пустые слайды: ---\n<!-- _class: page_section -->\n\n<hr/>\n\n---
pattern = r'---\s*\n<!--\s*_class:\s*page_section\s*-->\s*\n\s*<hr[^>]*>\s*\n\s*(?=---)'
content = re.sub(pattern, '', content, flags=re.MULTILINE)

with open('$LECTURE_FILE', 'w') as f:
    f.write(content)
"

elif [ -n "$ROUTE_START" ]; then
    echo -e "${BLUE}📄 Найден маршрут, создаем полную презентацию${NC}"

    # Титульный лист
    create_title_slide > "$LECTURE_FILE"

    # Основной контент от маршрута
    tail -n +$ROUTE_START "$INPUT_FILE" | \
        sed '/<!-- _class: course_page/,/^---$/d' | \
        sed '/<!-- _class: page_final/,$d' | \
        sed '/# Заполните.*опрос/,$d' | \
        sed '/# Приглашаем на следующий/,$d' >> "$LECTURE_FILE"

    # Завершающие слайды
    create_final_slides >> "$LECTURE_FILE"

    # Очищаем пустые слайды (слайды только с hr без контента)
    python3 -c "
import re
with open('$LECTURE_FILE', 'r') as f:
    content = f.read()

# Удаляем пустые слайды: ---\n<!-- _class: page_section -->\n\n<hr/>\n\n---
pattern = r'---\s*\n<!--\s*_class:\s*page_section\s*-->\s*\n\s*<hr[^>]*>\s*\n\s*(?=---)'
content = re.sub(pattern, '', content, flags=re.MULTILINE)

with open('$LECTURE_FILE', 'w') as f:
    f.write(content)
"

else
    echo -e "${YELLOW}⚠️  Маршрут не найден, создаем презентацию с содержимым как есть${NC}"

    # Титульный лист
    create_title_slide > "$LECTURE_FILE"

    # Основной контент
    if [ "$HAS_FRONT_MATTER" -gt 0 ]; then
        # Убираем front matter и служебные слайды
        sed '1,/^---$/d' "$INPUT_FILE" | \
            sed '/<!-- _class: course_page/,/^---$/d' | \
            sed '/<!-- _class: first_page/,/^---$/d' | \
            sed '/<!-- _class: second_page/,/^---$/d' | \
            sed '/<!-- _class: third_page/,/^---$/d' | \
            sed '/<!-- _class: page_rules/,/^---$/d' | \
            sed '/<!-- _class: page_final/,$d' >> "$LECTURE_FILE"
    else
        cat "$INPUT_FILE" | \
            sed '/<!-- _class: course_page/,/^---$/d' | \
            sed '/<!-- _class: first_page/,/^---$/d' | \
            sed '/<!-- _class: second_page/,/^---$/d' | \
            sed '/<!-- _class: third_page/,/^---$/d' | \
            sed '/<!-- _class: page_rules/,/^---$/d' | \
            sed '/<!-- _class: page_final/,$d' >> "$LECTURE_FILE"
    fi

    # Завершающие слайды
    create_final_slides >> "$LECTURE_FILE"

    # Очищаем пустые слайды (слайды только с hr без контента)
    python3 -c "
import re
with open('$LECTURE_FILE', 'r') as f:
    content = f.read()

# Удаляем пустые слайды: ---\n<!-- _class: page_section -->\n\n<hr/>\n\n---
pattern = r'---\s*\n<!--\s*_class:\s*page_section\s*-->\s*\n\s*<hr[^>]*>\s*\n\s*(?=---)'
content = re.sub(pattern, '', content, flags=re.MULTILINE)

with open('$LECTURE_FILE', 'w') as f:
    f.write(content)
"
fi

echo -e "${GREEN}✅ Файл создан: $LECTURE_FILE${NC}"

# Копируем resources если они есть
if [ -d "resources" ]; then
    echo -e "${BLUE}📸 Копируем ресурсы${NC}"
    cp -r resources/* "$COURSE_DIR/resources/"
    echo -e "${GREEN}✅ Ресурсы скопированы${NC}"
fi

# Генерируем фоновое изображение для карты знаний
if [ -n "$BACKGROUND_PROMPT" ]; then
    echo ""
    echo -e "${BLUE}🎨 Генерируем фоновое изображение для карты знаний${NC}"

    # Создаем временный markdown файл с промптом
    TEMP_MD=$(mktemp)
    cat > "$TEMP_MD" << EOF
---
marp: true
theme: otusnew-extended
---

<!-- _class: page -->

# Временный слайд для генерации фона

<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: $BACKGROUND_PROMPT, wide format 16:9, no text -->

Генерация фонового изображения для карты знаний.
EOF

    # Генерируем изображение через build-presentation.sh (без автооткрытия)
    cd "$COURSE_DIR"
    SKIP_OPEN=1 "$THEMES_DIR/build-presentation.sh" "$TEMP_MD" html > /dev/null 2>&1

    # Ищем сгенерированное изображение
    GENERATED_IMAGE=$(find resources -name "*_image_*_original.png" 2>/dev/null | head -1)
    if [ -n "$GENERATED_IMAGE" ]; then
        mv "$GENERATED_IMAGE" "resources/knowledge_map_bg.png"
        echo -e "${GREEN}✅ Фоновое изображение создано: resources/knowledge_map_bg.png${NC}"
    else
        echo -e "${YELLOW}⚠️  Фоновое изображение не сгенерировано. Будет использован стандартный фон.${NC}"
    fi

    # Очищаем временные файлы
    rm -f "$TEMP_MD"
    rm -rf generated
fi

# Генерируем артефакты
echo ""
echo -e "${BLUE}🏗️  Генерируем артефакты презентации${NC}"

# 1. HTML версия
echo -e "${BLUE}   📄 Создаем HTML версию${NC}"
SKIP_OPEN=1 "$THEMES_DIR/build-presentation.sh" "$LECTURE_FILE" html
echo -e "${GREEN}   ✅ HTML: generated/${TOPIC// /-}.html${NC}"

# 2. Single file bundle
echo -e "${BLUE}   📦 Создаем single file bundle${NC}"
cd "$THEMES_DIR"
HTML_FILE="$COURSE_DIR/generated/${TOPIC// /-}.html"
node bundle-html.js "$HTML_FILE" > /dev/null 2>&1
echo -e "${GREEN}   ✅ Bundle: generated/${TOPIC// /-}-bundled.html${NC}"

# 3. PDF версия
echo -e "${BLUE}   📋 Создаем PDF версию${NC}"
cd "$COURSE_DIR"
SKIP_OPEN=1 "$THEMES_DIR/build-presentation.sh" "$LECTURE_FILE" pdf
echo -e "${GREEN}   ✅ PDF: generated/${TOPIC// /-}.pdf${NC}"

# 4. PPTX версия
echo -e "${BLUE}   📊 Создаем PPTX версию${NC}"
SKIP_OPEN=1 "$THEMES_DIR/build-presentation.sh" "$LECTURE_FILE" pptx
echo -e "${GREEN}   ✅ PPTX: generated/${TOPIC// /-}.pptx${NC}"

# Итоговая информация
echo ""
echo -e "${GREEN}🎉 Релиз презентации готов!${NC}"
echo ""
echo -e "${BLUE}📁 Структура проекта:${NC}"
echo "   $COURSE_DIR/"
echo "   ├── ${TOPIC// /-}.md                   # Презентация по шаблону [S]"
echo "   ├── resources/                         # Ресурсы и изображения"
if [ -f "$COURSE_DIR/resources/knowledge_map_bg.png" ]; then
echo "   │   ├── knowledge_map_bg.png           # Кастомный фон карты знаний"
fi
echo "   │   └── ..."
echo "   └── generated/                         # Сгенерированные артефакты"
echo "       ├── ${TOPIC// /-}.html             # Интерактивная HTML версия"
echo "       ├── ${TOPIC// /-}-bundled.html     # Автономный bundle"
echo "       ├── ${TOPIC// /-}.pdf              # PDF для печати"
echo "       └── ${TOPIC// /-}.pptx             # PowerPoint презентация"
echo ""
echo -e "${BLUE}🚀 Команды для открытия:${NC}"
echo "   open '$COURSE_DIR/generated/${TOPIC// /-}.html'"
echo "   open '$COURSE_DIR/generated/${TOPIC// /-}-bundled.html'"
echo "   open '$COURSE_DIR/generated/${TOPIC// /-}.pdf'"
echo "   open '$COURSE_DIR/generated/${TOPIC// /-}.pptx'"
echo ""
echo -e "${YELLOW}💡 Презентация создана по шаблону [S]: маршрут → цели → секции → итоговые цели${NC}"