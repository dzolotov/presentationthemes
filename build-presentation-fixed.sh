#!/bin/bash

# build-presentation-fixed.sh
# Универсальный скрипт для генерации презентаций из Markdown с поддержкой Mermaid
# Использование: ./build-presentation-fixed.sh input.md [format] [output_file]
# Форматы: html (по умолчанию), pdf, pptx

set -e  # Останавливаемся при ошибках

# Добавляем Homebrew в PATH
export PATH="/opt/homebrew/bin:$PATH"

# Проверяем аргументы
if [ $# -lt 1 ]; then
    echo "Использование: $0 input.md [format] [output_file]"
    echo "Форматы: html, pdf, pptx"
    echo "Примеры:"
    echo "  $0 presentation.md"
    echo "  $0 presentation.md pdf"
    echo "  $0 presentation.md pptx output.pptx"
    exit 1
fi

INPUT_FILE="$1"
FORMAT="${2:-html}"  # По умолчанию HTML
INPUT_NAME=$(basename "${INPUT_FILE%.md}")
INPUT_DIR=$(dirname "$INPUT_FILE")

# Создаём директорию для результатов
GENERATED_DIR="${INPUT_DIR}/generated"
mkdir -p "$GENERATED_DIR"

# Определяем выходной файл
if [ $# -ge 3 ]; then
    OUTPUT_FILE="$3"
else
    OUTPUT_FILE="${GENERATED_DIR}/${INPUT_NAME}.${FORMAT}"
fi

# Для PDF/PPTX временный выходной файл будет в исходной директории
if [[ "$FORMAT" == "pdf" ]] || [[ "$FORMAT" == "pptx" ]]; then
    TEMP_OUTPUT_FILE="${INPUT_DIR}/${INPUT_NAME}.${FORMAT}"
else
    TEMP_OUTPUT_FILE="$OUTPUT_FILE"
fi

TEMP_FILE="${INPUT_DIR}/${INPUT_NAME}_temp.md"
RESOURCES_DIR="${GENERATED_DIR}/resources"

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Начинаем сборку презентации${NC}"
echo "   Входной файл: $INPUT_FILE"
echo "   Формат: $FORMAT"
echo "   Выходной файл: $OUTPUT_FILE"

# Проверяем формат
if [[ ! "$FORMAT" =~ ^(html|pdf|pptx)$ ]]; then
    echo -e "${RED}❌ Ошибка: неподдерживаемый формат '$FORMAT'${NC}"
    echo "   Поддерживаемые форматы: html, pdf, pptx"
    exit 1
fi

# Проверяем наличие входного файла
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}❌ Ошибка: файл $INPUT_FILE не найден${NC}"
    exit 1
fi

# Создаём каталог resources если его нет
if [ ! -d "$RESOURCES_DIR" ]; then
    echo -e "${BLUE}📁 Создаём каталог resources${NC}"
    mkdir -p "$RESOURCES_DIR"
fi

# ВАЖНОЕ ИЗМЕНЕНИЕ: Очищаем старые диаграммы для этой презентации
echo -e "${BLUE}🧹 Очищаем старые диаграммы${NC}"
rm -f "${RESOURCES_DIR}/${INPUT_NAME}_diagram_"*.svg
rm -f "${RESOURCES_DIR}/${INPUT_NAME}_diagram_"*.png

# Копируем исходный файл во временный
echo -e "${BLUE}📋 Создаём временную копию${NC}"
cp "$INPUT_FILE" "$TEMP_FILE"

# Создаём временный конфигурационный файл для Mermaid
MERMAID_CONFIG="${TEMP_FILE}.mermaid-config.json"
echo -e "${BLUE}⚙️  Создаём временную конфигурацию Mermaid${NC}"
cat > "$MERMAID_CONFIG" << 'EOF'
{
  "theme": "default",
  "themeVariables": {
    "fontSize": "14px",
    "fontFamily": "Roboto, sans-serif",
    "primaryColor": "#EEE",
    "primaryTextColor": "#333333",
    "primaryBorderColor": "#5B10B3",
    "lineColor": "#5B10B3",
    "secondaryColor": "#EEE",
    "tertiaryColor": "#f0f0f0",
    "background": "#ffffff",
    "mainBkg": "#EEE",
    "secondBkg": "#f5f5f5",
    "tertiaryBkg": "#f0f0f0",
    "nodeBkg": "#EEE",
    "textColor": "#333333",
    "labelBoxBkgColor": "#ffffff",
    "labelBoxBorderColor": "#5B10B3"
  },
  "flowchart": {
    "htmlLabels": true,
    "curve": "linear",
    "rankSpacing": 35,
    "nodeSpacing": 25,
    "padding": 15,
    "useMaxWidth": true,
    "diagramPadding": 20
  },
  "sequence": {
    "diagramMarginX": 50,
    "diagramMarginY": 10,
    "actorMargin": 50,
    "width": 150,
    "height": 65
  }
}
EOF

# Проверяем наличие mermaid блоков
if grep -q '```mermaid' "$TEMP_FILE"; then
    echo -e "${BLUE}🔍 Найдены Mermaid диаграммы${NC}"
    
    # Проверяем установлен ли mermaid-cli
    if ! command -v mmdc &> /dev/null; then
        echo -e "${BLUE}📦 Устанавливаем @mermaid-js/mermaid-cli${NC}"
        npm install -g @mermaid-js/mermaid-cli || {
            echo "   Глобальная установка не удалась, пробуем локально..."
            npm install @mermaid-js/mermaid-cli
            alias mmdc='npx mmdc'
        }
    fi
    
    # Счётчик для диаграмм
    COUNTER=1
    
    # ВАЖНОЕ ИЗМЕНЕНИЕ: Сначала извлекаем ВСЕ mermaid блоки
    echo -e "${BLUE}📊 Извлекаем все Mermaid диаграммы${NC}"
    
    # Создаём временный файл для обработки
    TEMP_PROCESS="${TEMP_FILE}.process"
    cp "$TEMP_FILE" "$TEMP_PROCESS"
    
    # Извлекаем и сохраняем все диаграммы
    while grep -q '```mermaid' "$TEMP_PROCESS"; do
        echo -e "${BLUE}   📊 Извлекаем диаграмму #${COUNTER}${NC}"
        
        # Извлекаем первый mermaid блок
        awk '/```mermaid/{flag=1; next} /```/{if(flag) exit} flag' "$TEMP_PROCESS" > "temp_diagram_${COUNTER}.mmd"
        
        # Удаляем извлечённый блок из временного файла
        awk '/```mermaid/ && !found {found=1; flag=1; next} /```/ && flag {flag=0; next} !flag {print}' "$TEMP_PROCESS" > "temp_process2.md"
        mv "temp_process2.md" "$TEMP_PROCESS"
        
        ((COUNTER++))
    done
    
    TOTAL_DIAGRAMS=$((COUNTER-1))
    echo -e "${GREEN}✅ Извлечено диаграмм: ${TOTAL_DIAGRAMS}${NC}"
    
    # Теперь обрабатываем каждую диаграмму
    COUNTER=1
    while [ $COUNTER -le $TOTAL_DIAGRAMS ]; do
        echo -e "${BLUE}   🎨 Генерируем изображение для диаграммы #${COUNTER}${NC}"
        
        # Определяем тип диаграммы для имени файла
        DIAGRAM_TYPE=""
        if grep -q "graph LR\|graph RL" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_horizontal"
        elif grep -q "graph TD\|graph TB" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_vertical"
        elif grep -q "sequenceDiagram" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_sequence"
        elif grep -q "gantt" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_gantt"
        elif grep -q "flowchart" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_flowchart"
        fi
        
        echo "      Тип: $DIAGRAM_TYPE"
        
        # Для PPTX и PDF используем PNG, для HTML - SVG
        if [[ "$FORMAT" == "pptx" ]] || [[ "$FORMAT" == "pdf" ]]; then
            IMAGE_EXT="png"
            OUTPUT_FORMAT="--outputFormat=png"
        else
            IMAGE_EXT="svg"
            OUTPUT_FORMAT=""
        fi
        
        # Имя выходного файла
        IMAGE_FILENAME="${INPUT_NAME}_diagram_${COUNTER}${DIAGRAM_TYPE}.${IMAGE_EXT}"
        IMAGE_PATH="${RESOURCES_DIR}/${IMAGE_FILENAME}"
        
        echo "      Выходной файл: $IMAGE_FILENAME"
        
        # Для вертикальных диаграмм используем другие размеры
        if [[ "$DIAGRAM_TYPE" == "_vertical" ]]; then
            if [[ "$FORMAT" == "pdf" ]]; then
                WIDTH=500
                HEIGHT=600
            else
                WIDTH=600
                HEIGHT=800
            fi
        else
            WIDTH=900
            HEIGHT=500
        fi
        
        # Для PPTX и PDF увеличиваем размеры для лучшего качества
        if [[ "$FORMAT" == "pptx" ]] || [[ "$FORMAT" == "pdf" ]]; then
            WIDTH=$((WIDTH * 2))
            HEIGHT=$((HEIGHT * 2))
        fi
        
        # Генерируем изображение
        mmdc -i "temp_diagram_${COUNTER}.mmd" \
             -o "$IMAGE_PATH" \
             -c "$MERMAID_CONFIG" \
             -w $WIDTH \
             -H $HEIGHT \
             $OUTPUT_FORMAT \
             --backgroundColor white || {
            echo -e "${RED}❌ Ошибка при генерации ${IMAGE_EXT^^} для диаграммы #${COUNTER}${NC}"
            exit 1
        }
        
        ((COUNTER++))
    done
    
    # Теперь заменяем mermaid блоки на изображения
    echo -e "${BLUE}🔄 Заменяем Mermaid блоки на изображения${NC}"
    
    COUNTER=1
    while [ $COUNTER -le $TOTAL_DIAGRAMS ]; do
        # Определяем тип диаграммы снова
        DIAGRAM_TYPE=""
        if grep -q "graph LR\|graph RL" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_horizontal"
        elif grep -q "graph TD\|graph TB" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_vertical"
        elif grep -q "sequenceDiagram" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_sequence"
        elif grep -q "gantt" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_gantt"
        elif grep -q "flowchart" "temp_diagram_${COUNTER}.mmd"; then
            DIAGRAM_TYPE="_flowchart"
        fi
        
        # Для PPTX и PDF используем PNG, для HTML - SVG
        if [[ "$FORMAT" == "pptx" ]] || [[ "$FORMAT" == "pdf" ]]; then
            IMAGE_EXT="png"
        else
            IMAGE_EXT="svg"
        fi
        
        # Имя файла изображения
        IMAGE_FILENAME="${INPUT_NAME}_diagram_${COUNTER}${DIAGRAM_TYPE}.${IMAGE_EXT}"
        
        # Относительный путь для вставки в Markdown
        if [[ "$FORMAT" == "html" ]]; then
            IMAGE_RELATIVE_PATH="resources/${IMAGE_FILENAME}"
        else
            IMAGE_RELATIVE_PATH="generated/resources/${IMAGE_FILENAME}"
        fi
        
        # Заменяем mermaid блок на изображение
        case "$FORMAT" in
            "pdf")
                awk -v img_path="$IMAGE_RELATIVE_PATH" '
                    /```mermaid/ && !replaced {
                        print ""
                        print ""
                        printf "![](%s)\n", img_path
                        print ""
                        print ""
                        flag=1
                        replaced=1
                        next
                    }
                    /```/ && flag {
                        flag=0
                        next
                    }
                    !flag { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
            "pptx")
                awk -v img_path="$IMAGE_RELATIVE_PATH" '
                    /```mermaid/ && !replaced {
                        print ""
                        print ""
                        printf "![](%s)\n", img_path
                        print ""
                        print ""
                        flag=1
                        replaced=1
                        next
                    }
                    /```/ && flag {
                        flag=0
                        next
                    }
                    !flag { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
            "html")
                awk -v img_path="$IMAGE_RELATIVE_PATH" '
                    /```mermaid/ && !replaced {
                        print "<div style=\"display: flex; justify-content: center; align-items: center; width: 100%; height: 100%;\">"
                        printf "  <img src=\"%s\" style=\"max-width: 90%%; max-height: 380px;\" />\n", img_path
                        print "</div>"
                        flag=1
                        replaced=1
                        next
                    }
                    /```/ && flag {
                        flag=0
                        next
                    }
                    !flag { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
        esac
        
        mv "temp_output.md" "$TEMP_FILE"
        
        ((COUNTER++))
    done
    
    # Очистка временных файлов диаграмм
    rm -f temp_diagram_*.mmd
    rm -f "$TEMP_PROCESS"
    
    echo -e "${GREEN}✅ Все диаграммы обработаны${NC}"
else
    echo -e "${BLUE}ℹ️  Mermaid диаграммы не найдены${NC}"
fi

# Корректируем пути к изображениям и скриптам только для HTML
if [[ "$FORMAT" == "html" ]]; then
    echo -e "${BLUE}🔧 Корректируем пути к изображениям и скриптам для HTML${NC}"
    
    # Создаём временный файл для обработки
    TEMP_SED="${TEMP_FILE}.sed"
    
    # Используем perl для более надёжной обработки
    if command -v perl &> /dev/null; then
        perl -pe '
            # Markdown изображения ![alt](path) - БЕЗ SVG (SVG остаются как есть для HTML)
            s/!\[([^\]]*)\]\((?!http|https|\/|\.\.\/|#)([^)]+\.(png|jpg|jpeg|gif|webp))\)/![$1](..\/\2)/g;
            
            # HTML img теги - БЕЗ SVG
            s/src="(?!http|https|\/|\.\.\/|#)([^"]+\.(png|jpg|jpeg|gif|webp))"/src="..\/\1"/g;
            s/src=\x27(?!http|https|\/|\.\.\/|#)([^\x27]+\.(png|jpg|jpeg|gif|webp))\x27/src="..\/\1"/g;
            
            # JavaScript файлы в script тегах
            s/src="(?!http|https|\/|\.\.\/|#)([^"]+\.js)"/src="..\/\1"/g;
            s/src=\x27(?!http|https|\/|\.\.\/|#)([^\x27]+\.js)\x27/src="..\/\1"/g;
        ' "$TEMP_FILE" > "$TEMP_SED"
    else
        # Альтернативный вариант с простой заменой через while read
        while IFS= read -r line; do
            # Заменяем простые случаи ![](file.ext) - БЕЗ SVG
            line=$(echo "$line" | sed -E 's/!\[([^]]*)\]\(([^/:)]+\.(png|jpg|jpeg|gif|webp))\)/![\1](..\/\2)/g')
            # Заменяем <img src="file.ext"> - БЕЗ SVG
            line=$(echo "$line" | sed -E 's/src="([^/:"][^/"]+\.(png|jpg|jpeg|gif|webp))"/src="..\/\1"/g')
            # Заменяем <script src="file.js">
            line=$(echo "$line" | sed -E 's/src="([^/:"][^/"]+\.js)"/src="..\/\1"/g')
            echo "$line"
        done < "$TEMP_FILE" > "$TEMP_SED"
    fi
    
    mv "$TEMP_SED" "$TEMP_FILE"
fi

# Для PDF/PPTX заменяем интерактивные элементы на плейсхолдеры
if [[ "$FORMAT" == "pdf" ]] || [[ "$FORMAT" == "pptx" ]]; then
    echo -e "${BLUE}🖼️  Заменяем интерактивные элементы на плейсхолдеры для ${FORMAT_UPPER}${NC}"
    
    # Создаём временный файл для обработки
    TEMP_INTERACTIVE="${TEMP_FILE}.interactive"
    
    # Используем perl для обработки
    if command -v perl &> /dev/null; then
        perl -0777 -pe '
            # Заменяем блоки с любым id="*-viz"
            s{<div[^>]*text-align:\s*center[^>]*>.*?<svg\s+id="([^"]+)-viz".*?</div>\s*<!--[^>]*-->.*?<script[^>]*>.*?</script>}
             {![Интерактивная демонстрация $1 доступна в HTML версии]($1.png)}gs;
            
            # Удаляем все script теги
            s{<script[^>]*>.*?</script>}{}gs;
        ' "$TEMP_FILE" > "$TEMP_INTERACTIVE"
    else
        # Запасной вариант с sed
        # Заменяем блоки с svg на изображения
        sed -E '
            # Для строк с svg и id="-viz"
            /<svg[^>]*id="[^"]+-viz"/ {
                # Извлекаем имя
                s/.*id="([^"]+)-viz".*/![Интерактивная демонстрация \1 доступна в HTML версии](\1.png)/
            }
            # Удаляем строки с button
            /<button/d
            # Удаляем строки с br
            /<br>/d
            # Удаляем script теги
            /<script.*\.js/d
            /<script.*d3js/d
            /<\/script>/d
        ' "$TEMP_FILE" > "$TEMP_INTERACTIVE"
    fi
    
    mv "$TEMP_INTERACTIVE" "$TEMP_FILE"
fi

# Запускаем Marp для генерации выходного файла
FORMAT_UPPER=$(echo "$FORMAT" | tr '[:lower:]' '[:upper:]')
echo -e "${BLUE}🎨 Генерируем ${FORMAT_UPPER} с помощью Marp${NC}"

# Проверяем наличие Marp
MARP_CMD=""
if [ -f "/opt/homebrew/bin/marp" ]; then
    MARP_CMD="/opt/homebrew/bin/marp"
elif command -v marp &> /dev/null; then
    MARP_CMD="marp"
else
    echo -e "${RED}❌ Ошибка: Marp CLI не найден${NC}"
    echo "   Установите его командой: npm install -g @marp-team/marp-cli"
    exit 1
fi

# Определяем параметры для разных форматов
case "$FORMAT" in
    "html")
        FORMAT_ARGS="--html"
        THEME_FILE="~/Obsidian/MySecureNotes/.themes/otusnew.css"
        ;;
    "pdf")
        FORMAT_ARGS="--pdf --pdf-notes"
        THEME_FILE="~/Obsidian/MySecureNotes/.themes/otusnew.css"
        ;;
    "pptx")
        FORMAT_ARGS="--pptx"
        THEME_FILE="~/Obsidian/MySecureNotes/.themes/otusnew.css"
        ;;
esac

# Генерируем выходной файл
$MARP_CMD "$TEMP_FILE" \
    $FORMAT_ARGS \
    --theme $THEME_FILE \
    --theme-set ~/Obsidian/MySecureNotes/.themes \
    --allow-local-files \
    --no-stdin \
    -o "$TEMP_OUTPUT_FILE" || {
    echo -e "${RED}❌ Ошибка при генерации ${FORMAT_UPPER}${NC}"
    exit 1
}

# Перемещаем файл в generated для PDF/PPTX
if [[ "$FORMAT" == "pdf" ]] || [[ "$FORMAT" == "pptx" ]]; then
    echo -e "${BLUE}📦 Перемещаем ${FORMAT_UPPER} в каталог generated${NC}"
    mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
fi

# Удаляем временные файлы
echo -e "${BLUE}🧹 Очистка временных файлов${NC}"
rm -f "$TEMP_FILE" "$MERMAID_CONFIG"

echo -e "${GREEN}✅ Готово!${NC}"
echo "   Файл презентации: $OUTPUT_FILE"
if [[ "$FORMAT" == "pptx" ]]; then
    echo "   PNG диаграммы: $RESOURCES_DIR/"
else
    echo "   SVG диаграммы: $RESOURCES_DIR/"
fi