#!/bin/bash

# build-presentation.sh
# Универсальный скрипт для генерации презентаций из Markdown с поддержкой Mermaid и Gnuplot
# Использование: ./build-presentation.sh input.md [format] [output_file]
# Форматы: html (по умолчанию), pdf, pptx

set -e  # Останавливаемся при ошибках

# Добавляем Homebrew в PATH
export PATH="/opt/homebrew/bin:$PATH"

# Функция для создания миникарты навигации
create_minimap() {
    local input_file="$1"
    local output_file="$2"
    local generated_dir="$3"

    echo "   📋 Анализируем секции презентации"

    # Извлекаем темы и эмоджи из data-topic атрибутов
    local topics=()
    local topic_emojis_extracted=()
    local full_topics=()  # Полные названия с эмоджи для data-topic
    local added_topics=()

    while IFS= read -r line; do
        # Найдена тема в data-topic - извлекаем название с эмоджи
        if [[ "$line" =~ data-topic=\"([^\"]+)\" ]]; then
            local full_topic="${BASH_REMATCH[1]}"

            # Извлекаем эмоджи и название
            local emoji="🔧"  # по умолчанию
            local topic_name="$full_topic"

            # Простая таблица соответствий - проверяем каждый эмоджи по отдельности
            case "$full_topic" in
                "🏗️ Настройка")
                    emoji="🏗️"
                    topic_name="Настройка"
                    ;;
                "🐳 Docker")
                    emoji="🐳"
                    topic_name="Docker"
                    ;;
                "🛡️ Безопасность")
                    emoji="🛡️"
                    topic_name="Безопасность"
                    ;;
                "🧪 Тестирование")
                    emoji="🧪"
                    topic_name="Тестирование"
                    ;;
                "⚡ Оптимизация")
                    emoji="⚡"
                    topic_name="Оптимизация"
                    ;;
                "🔧 Pipeline")
                    emoji="🔧"
                    topic_name="Pipeline"
                    ;;
                "📊 Мониторинг")
                    emoji="📊"
                    topic_name="Мониторинг"
                    ;;
                "💼 Практика")
                    emoji="💼"
                    topic_name="Практика"
                    ;;
                "📝 Задание")
                    emoji="📝"
                    topic_name="Задание"
                    ;;
                *)
                    # Общий случай - пробуем разделить по первому пробелу
                    if [[ "$full_topic" =~ ^([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
                        emoji="${BASH_REMATCH[1]}"
                        topic_name="${BASH_REMATCH[2]}"
                    fi
                    ;;
            esac

            # Добавляем тему в уникальный список
            local already_exists=false
            for existing_topic in "${topics[@]}"; do
                if [[ "$existing_topic" == "$topic_name" ]]; then
                    already_exists=true
                    break
                fi
            done

            if [[ "$already_exists" == false ]]; then
                topics+=("$topic_name")
                topic_emojis_extracted+=("$emoji")
                full_topics+=("$full_topic")  # Сохраняем полное название
            fi
        fi
    done < "$input_file"

    if [ ${#topics[@]} -eq 0 ]; then
        echo "   ⚠️  Секции с data-topic не найдены, пропускаем миникарту"
        return
    fi

    echo "   🎯 Найдено уникальных тем: ${#topics[@]} (${topics[*]})"
    echo "   🔍 Эмоджи для тем: (${topic_emojis_extracted[*]})"

    # Создаем CSS файл миникарты
    cat > "${generated_dir}/minimap.css" << 'EOF'
:root{
  --mm-bg:#000000B3;
  --mm-border:#FFFFFF26;
  --mm-primary: var(--color-primary, #8F5FE7);
  --mm-accent: var(--color-accent, #FF9800);
  --mm-text:#fff;
  --mm-muted:#C7C7C7;
}

/* Тонкая полоса общего прогресса (видна всегда) */
#mm-progressbar{
  position: fixed; left: 0; right: 0; bottom: 0; height: 6px;
  background: #FFFFFF1A; z-index: 9998;
}
#mm-progressbar > i{
  display: block; height: 100%; width: 0%;
  background: linear-gradient(90deg,var(--mm-primary),var(--mm-accent));
  transition: width .25s ease;
}

/* Вертикальная мини-карта справа сверху */
#minimap{
  position: fixed; right: 16px; top: 16px; z-index: 9999;
  background: var(--mm-bg); backdrop-filter: blur(6px);
  border: 1px solid var(--mm-border); border-radius: 12px; color:#fff;
  width: 280px; padding: 12px;
  font-family: Roboto, sans-serif; user-select: none;
  opacity: 0.5;
}
#minimap:not(.mm-visible){ display: none; }

/* Внутри карточки: только темы (бейджи) */
#minimap .mm-topics{ display: grid; grid-template-columns: 1fr; gap: 6px; }
#minimap .mm-topic{
  background: var(--mm-bg); border: 1px solid var(--mm-border); border-radius: 8px;
  color: var(--mm-text); padding: 6px 8px; display: grid;
  grid-template-columns: auto 1fr auto; grid-template-rows: auto auto; gap: 3px 6px; align-items: center;
}
#minimap .mm-topic .ico{ grid-column: 1; grid-row: 1 / span 2; }
#minimap .mm-topic .name{ grid-column: 2; grid-row: 1; font-weight: 600; font-size: 13px; }
#minimap .mm-topic .done{ grid-column: 3; grid-row: 1; opacity: 0; transition: opacity .2s; }
#minimap .mm-topic.visited .done{ opacity: 1; }
#minimap .mm-topic .sub{ grid-column: 2 / span 2; grid-row: 2; height: 4px; background:#FFFFFF26; border-radius: 999px; overflow: hidden; }
#minimap .mm-topic .sub > i{ display:block; height:100%; width:0%; background: var(--mm-primary); transition: width .25s ease; }

#minimap .mm-topic.current{
  outline: 2px solid var(--mm-accent); outline-offset: 2px;
  background: var(--mm-accent);
  background: linear-gradient(135deg, var(--mm-accent)20, transparent);
}
#minimap .mm-topic.current .name{
  font-weight: 700;
  color: var(--mm-accent);
}
#minimap .mm-topic.visited{
  background: #1a7f3730;
}
#minimap .mm-topic.visited .name{
  opacity: 0.8;
}

/* Ограничиваем ширину заголовков на page_section, чтобы не перекрывались миникартой */
section.page_section h1 {
  max-width: 650px !important;
}
EOF


    # Создаем JavaScript файл миникарты
    cat > "${generated_dir}/minimap.js" << 'EOF'
(function(){
  console.log('Minimap script started');

  function initMinimap() {
    // Пробуем разные селекторы для поиска слайдов
    let slides = Array.from(document.querySelectorAll('svg.bespoke-marp-slide'));
    if (!slides.length) {
      slides = Array.from(document.querySelectorAll('svg[data-marpit-svg]'));
    }
    if (!slides.length) {
      slides = Array.from(document.querySelectorAll('section[data-theme]'));
    }
    console.log('Found slides:', slides.length);
    if (!slides.length) return;

    initMinimapLogic(slides);
  }

  function initMinimapLogic(slides) {

  // Врезки создаём один раз, если их нет
  if (!document.getElementById('mm-progressbar')){
    const bar = document.createElement('div');
    bar.id = 'mm-progressbar';
    bar.innerHTML = '<i></i>';
    document.body.appendChild(bar);
  }
  if (!document.getElementById('minimap')){
    const box = document.createElement('div');
    box.id = 'minimap';
    box.innerHTML = `
      <div class="mm-topics">
EOF

    # Добавляем темы в JavaScript - используем извлеченные темы и эмоджи
    for i in "${!topics[@]}"; do
        local topic_name="${topics[$i]}"
        local emoji="${topic_emojis_extracted[$i]:-🔧}"
        local full_topic_name="${full_topics[$i]}"

        cat >> "${generated_dir}/minimap.js" << EOF
        <div class="mm-topic" data-topic="$full_topic_name"><span class="ico">$emoji</span><span class="name">$topic_name</span><span class="done">✓</span><span class="sub"><i></i></span></div>
EOF
    done

    # Завершаем JavaScript файл
    cat >> "${generated_dir}/minimap.js" << 'EOF'
      </div>`;
    document.body.appendChild(box);
  }

  const mm = document.getElementById('minimap');
  const topicEls = Array.from(mm.querySelectorAll('.mm-topic'));
  const barFill = document.querySelector('#mm-progressbar > i');

  // Тема слайда читается из скрытого блока .slide-meta: data-topic
  // Если нет data-topic, ищем ближайшую предыдущую тему
  const slideTopics = [];
  const topicIndex = new Map(); // topic => { total, seen }
  let currentTopic = 'Misc';

  slides.forEach((svg, idx) => {
    const meta = svg.querySelector('.slide-meta');
    const tset = new Set();

    if (meta?.dataset.topic) {
      // Это основная секция с темой - извлекаем название без эмоджи
      let fullTopic = meta.dataset.topic.trim();
      // Убираем эмоджи из начала строки (с учетом модификаторов)
      let topicName = fullTopic.replace(/^[🏗🐳🛡🧪⚡🔧📊💼📝🚀⚙🗄🌐🔌🎨📱☁📈🔄][^\s]*\s+/, '');
      currentTopic = topicName;
      tset.add(currentTopic);
    } else {
      // Обычный слайд - относим к текущей теме
      tset.add(currentTopic);
    }

    slideTopics[idx] = Array.from(tset);
    slideTopics[idx].forEach(t => {
      if (!topicIndex.has(t)) topicIndex.set(t, { total: 0, seen: 0 });
      topicIndex.get(t).total += 1;
    });
  });

  const btnByTopic = new Map(topicEls.map(el => {
    // Извлекаем название темы без эмоджи из data-topic для сопоставления
    let topicKey = el.dataset.topic.replace(/^[🏗🐳🛡🧪⚡🔧📊💼📝🚀⚙🗄🌐🔌🎨📱☁📈🔄][^\s]*\s+/, '');
    return [topicKey, el];
  }));

  // Набор посещённых слайдов - восстанавливаем из localStorage
  let visitedArray = [];
  try {
    visitedArray = JSON.parse(localStorage.getItem('minimap-visited') || '[]');
  } catch (e) {}
  const visited = new Set(visitedArray);
  console.log('Restored visited slides:', visitedArray);
  window.__mmVisited = visited;

  // Отслеживание последнего индекса для определения направления
  let lastIndex = parseInt(localStorage.getItem('minimap-last-index') || '0');

  // Сохраняем состояние в localStorage
  function saveVisited() {
    try {
      localStorage.setItem('minimap-visited', JSON.stringify(Array.from(visited)));
      localStorage.setItem('minimap-last-index', lastIndex.toString());
    } catch (e) {}
  }

  function activeIndex(){
    const ix = slides.findIndex(s => s.classList.contains('bespoke-marp-active'));
    return ix >= 0 ? ix : 0;
  }

  function isMinimapSlide(svg){
    // Показывать мини-карту только на слайдах page_section
    const section = svg.querySelector('foreignObject > section');
    return section && (
      section.classList.contains('page_section') ||
      section.dataset?.class === 'page_section'
    );
  }

  function isSectionBoundary(svg){
    // Границы секций: page_section И page_twocolumn
    const section = svg.querySelector('foreignObject > section');
    return section && (
      section.classList.contains('page_section') ||
      section.dataset?.class === 'page_section' ||
      section.classList.contains('page_twocolumn') ||
      section.dataset?.class === 'page_twocolumn'
    );
  }

  function update(){
    const ix = activeIndex();

    // Определяем направление навигации
    const isForward = ix > lastIndex;
    const isBackward = ix < lastIndex;

    console.log(`Navigation: ${lastIndex} -> ${ix}, forward: ${isForward}, backward: ${isBackward}`);

    if (isForward) {
      // Движемся вперед - добавляем в посещенные
      if (!visited.has(ix)) {
        visited.add(ix);
        console.log(`Added slide ${ix} to visited`);
      }
    } else if (isBackward) {
      // Движемся назад - удаляем слайды после текущего
      const toRemove = Array.from(visited).filter(i => i > ix);
      toRemove.forEach(i => visited.delete(i));
      if (toRemove.length > 0) {
        console.log(`Removed slides ${toRemove} from visited`);
      }
    }

    // Обновляем lastIndex и сохраняем состояние
    lastIndex = ix;
    saveVisited();

    // Текущие темы - считаем прогресс без учета текущего слайда
    topicIndex.forEach(v => v.seen = 0);
    visited.forEach(i => {
      if (i !== ix) { // исключаем текущий слайд
        (slideTopics[i]||[]).forEach(t => {
          const r = topicIndex.get(t);
          if (r) r.seen += 1;
        });
      }
    });

    const current = new Set(slideTopics[ix] || []);

    btnByTopic.forEach((btn, t) => {
      const rec = topicIndex.get(t) || { total: 0, seen: 0 };
      const pct = rec.total ? Math.round((rec.seen/rec.total)*100) : 0;
      btn.querySelector('.sub > i').style.width = pct + '%';
      btn.classList.toggle('visited', rec.seen > 0);
      btn.classList.toggle('current', current.has(t));
    });

    // Прогресс-бар внизу: показывать прогресс в текущей теме на обычных слайдах
    const currentSlide = slides[ix];
    const section = currentSlide.querySelector('foreignObject > section');
    const meta = currentSlide.querySelector('.slide-meta');
    const isQuestionSlide = section?.classList.contains('page_questions') || section?.dataset?.class === 'page_questions';
    // Слайд является секционным только если он начинает новую тему (имеет data-topic)
    const isSectionSlide = meta?.dataset?.topic ? true : false;

    if (!isQuestionSlide && !isSectionSlide && current.size > 0) {
      // Получаем текущую тему
      let currentTopic = null;
      for (let i = ix; i >= 0; i--) {
        const slideMeta = slides[i].querySelector('.slide-meta');
        if (slideMeta?.dataset.topic) {
          currentTopic = slideMeta.dataset.topic;
          break;
        }
      }

      if (currentTopic) {
        // Находим все слайды с той же темой
        let topicSlides = [];
        for (let i = 0; i < slides.length; i++) {
          const slideMeta = slides[i].querySelector('.slide-meta');
          if (slideMeta?.dataset.topic === currentTopic) {
            topicSlides.push(i);
          }
        }

        // Находим первый и последний слайд с этой темой
        const firstTopicSlide = Math.min(...topicSlides);

        // Находим следующий слайд с ДРУГОЙ темой (конец всей секции этой темы)
        let sectionEnd = slides.length;
        for (let i = Math.max(...topicSlides) + 1; i < slides.length; i++) {
          const slideMeta = slides[i].querySelector('.slide-meta');
          if (slideMeta?.dataset.topic && slideMeta.dataset.topic !== currentTopic) {
            sectionEnd = i;
            break;
          }
        }

        // Позиция текущего слайда относительно первого слайда темы
        const positionInSection = ix - firstTopicSlide;
        const sectionLength = sectionEnd - firstTopicSlide;
        const sectionProgressPercent = sectionLength > 1 ? Math.round((positionInSection / (sectionLength - 1)) * 100) : 0;

        // Отладка
        const currentSlideTitle = currentSlide.querySelector('h1')?.textContent || 'Без заголовка';
        console.log(`Слайд "${currentSlideTitle}" (${ix+1}): тема "${currentTopic}", секция ${firstTopicSlide+1}-${sectionEnd}, позиция в секции: ${positionInSection+1}/${sectionLength}, прогресс: ${sectionProgressPercent}%`);

        barFill.style.width = sectionProgressPercent + '%';
        document.getElementById('mm-progressbar').style.display = 'block';
      } else {
        document.getElementById('mm-progressbar').style.display = 'none';
      }
    } else {
      // Скрываем прогресс-бар на вопросах и секциях
      document.getElementById('mm-progressbar').style.display = 'none';
    }

    // Видимость миникарты только на секциях
    mm.classList.toggle('mm-visible', isMinimapSlide(currentSlide) || mm.classList.contains('mm-forced'));
  }

  // Навигация по темам кликом — к первому слайду темы
  topicEls.forEach(btn => {
    btn.addEventListener('click', () => {
      const t = btn.dataset.topic;
      const j = slides.findIndex((_, i) => (slideTopics[i]||[]).includes(t));
      if (j >= 0){
        slides[activeIndex()].classList.remove('bespoke-marp-active');
        slides[j].classList.add('bespoke-marp-active'); // имитация перехода
        update();
      }
    });
  });

  // Вертикальная миникарта всегда видна

  // Хоткей M — принудительный показ/скрытие миникарты на любом слайде
  document.addEventListener('keydown', (e) => {
    if (e.key.toLowerCase() === 'm'){
      mm.classList.toggle('mm-forced');
      update();
    } else {
      // Неблокирующее обновление после стандартной навигации
      setTimeout(update, 0);
    }
  });

  document.addEventListener('click', () => setTimeout(update, 0));

  // Реакция на смену активного слайда (класс .bespoke-marp-active ставит Bespoke)
  const obs = new MutationObserver(() => update());
  slides.forEach(s => obs.observe(s, { attributes:true, attributeFilter:['class'] }));

  // Первичная инициализация
  update();
  } // конец initMinimapLogic

  // Ждем загрузки DOM и повторяем попытки
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMinimap);
  } else {
    initMinimap();
  }

  // Дополнительная попытка через 500ms для bundle
  setTimeout(initMinimap, 500);
})();
EOF

    # Копируем knowledge-map скрипт из .themes директории и создаем настройки
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    KNOWLEDGE_MAP_SOURCE="${SCRIPT_DIR}/knowledge-map-new.js"

    # Добавляем карту знаний только если есть кастомный фон
    if [ -f "$KNOWLEDGE_MAP_SOURCE" ] && [ -f "resources/knowledge_map_bg.png" ]; then
        echo "   🗺️  Добавляем карту знаний"
        local bg_image="resources/knowledge_map_bg.png"
        echo "   🖼️  Используется кастомное фоновое изображение: $bg_image"

        # Копируем knowledge-map скрипт с настройкой изображения
        sed "s|imageUrl: 'resources/image_kubernetes.png'|imageUrl: '$bg_image'|" "$KNOWLEDGE_MAP_SOURCE" > "${generated_dir}/knowledge-map-new.js"
        echo "   📋 Скопирован knowledge-map-new.js из .themes (настроено фоновое изображение: $bg_image)"
    else
        echo "   ℹ️  Карта знаний отключена (нет кастомного фона knowledge_map_bg.png)"
    fi

    # Добавляем ссылки на CSS и JS в HTML файл
    echo "   🔗 Подключаем CSS и JavaScript файлы"
    if [ -f "${generated_dir}/knowledge-map-new.js" ]; then
        # С картой знаний
        sed -i.bak 's|</style></head>|</style><link rel="stylesheet" href="minimap.css"><script src="minimap.js" defer></script><script src="knowledge-map-new.js" defer></script></head>|' "$output_file"
    else
        # Только миникарта
        sed -i.bak 's|</style></head>|</style><link rel="stylesheet" href="minimap.css"><script src="minimap.js" defer></script></head>|' "$output_file"
    fi
    rm -f "${output_file}.bak"

    echo "   ✅ Миникарта создана и подключена"
}

# Проверяем аргументы
if [ $# -lt 1 ]; then
    echo "Использование: $0 input.md [format] [theme] [output_file]"
    echo "Форматы: html, pdf, pptx"
    echo "Темы: otus (по умолчанию), yandex, openlesson"
    echo "Примеры:"
    echo "  $0 presentation.md"
    echo "  $0 presentation.md html otus"
    echo "  $0 presentation.md html yandex"
    echo "  $0 presentation.md html openlesson"
    echo "  $0 presentation.md pdf yandex"
    echo "  $0 presentation.md pptx otus output.pptx"
    exit 1
fi

INPUT_FILE="$1"
FORMAT="${2:-html}"  # По умолчанию HTML
THEME="${3:-otus}"   # По умолчанию OTUS
INPUT_NAME=$(basename "${INPUT_FILE%.md}")
INPUT_DIR=$(dirname "$INPUT_FILE")

# Создаём директорию для результатов
GENERATED_DIR="${INPUT_DIR}/generated"
mkdir -p "$GENERATED_DIR"

# Определяем выходной файл
if [ $# -ge 4 ]; then
    OUTPUT_FILE="$4"
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
# Папка для постоянных изображений (пользовательские + DALL-E)
STATIC_RESOURCES_DIR="${INPUT_DIR}/resources"

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Начинаем сборку презентации${NC}"
echo "   Входной файл: $INPUT_FILE"
echo "   Формат: $FORMAT"
echo "   Тема: $THEME"
echo "   Выходной файл: $OUTPUT_FILE"

# Проверяем формат
if [[ ! "$FORMAT" =~ ^(html|pdf|pptx)$ ]]; then
    echo -e "${RED}❌ Ошибка: неподдерживаемый формат '$FORMAT'${NC}"
    echo "   Поддерживаемые форматы: html, pdf, pptx"
    exit 1
fi

# Проверяем тему
if [[ ! "$THEME" =~ ^(otus|yandex|openlesson)$ ]]; then
    echo -e "${RED}❌ Ошибка: неподдерживаемая тема '$THEME'${NC}"
    echo "   Поддерживаемые темы: otus, yandex, openlesson"
    exit 1
fi

# Определяем имя темы на основе выбранной темы и формата
case "$THEME" in
    "otus")
        THEME_NAME="otusnew-extended"
        ;;
    "yandex")
        if [[ "$FORMAT" == "pdf" ]]; then
            THEME_NAME="yandex-extended-pdf"
        else
            THEME_NAME="yandex-extended"
        fi
        ;;
    "openlesson")
        if [[ "$FORMAT" == "pdf" ]]; then
            THEME_NAME="openlesson-extended-pdf"
        else
            THEME_NAME="openlesson-extended"
        fi
        ;;
    *)
        echo -e "${RED}❌ Ошибка: неподдерживаемая тема '$THEME'${NC}"
        exit 1
        ;;
esac

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

# Копируем все изображения из локальной папки resources в generated/resources
if [ -d "${INPUT_DIR}/resources" ]; then
    echo -e "${BLUE}📸 Копируем изображения из resources в generated/resources${NC}"
    
    # Копируем webp файлы
    if ls "${INPUT_DIR}"/resources/*.webp 2>/dev/null | grep -q .; then
        cp "${INPUT_DIR}"/resources/*.webp "$RESOURCES_DIR/" 2>/dev/null
        echo "   Скопированы webp файлы"
    fi
    
    # Копируем png файлы (исключая служебные файлы карты знаний)
    if ls "${INPUT_DIR}"/resources/*.png 2>/dev/null | grep -q .; then
        # Копируем все png файлы кроме служебных image_kubernetes.png и image_default.png
        find "${INPUT_DIR}/resources" -name "*.png" ! -name "image_kubernetes.png" ! -name "image_default.png" -exec cp {} "$RESOURCES_DIR/" \; 2>/dev/null
        echo "   Скопированы png файлы (исключая служебные файлы карты знаний)"

        # Отдельно копируем knowledge_map_bg.png если он есть (для карты знаний)
        if [ -f "${INPUT_DIR}/resources/knowledge_map_bg.png" ]; then
            cp "${INPUT_DIR}/resources/knowledge_map_bg.png" "$RESOURCES_DIR/"
            echo "   ✅ Скопирован кастомный фон карты знаний: knowledge_map_bg.png"
        fi
    fi
    
    # Копируем jpg/jpeg файлы
    if ls "${INPUT_DIR}"/resources/*.jpg 2>/dev/null | grep -q .; then
        cp "${INPUT_DIR}"/resources/*.jpg "$RESOURCES_DIR/" 2>/dev/null
        echo "   Скопированы jpg файлы"
    fi
    if ls "${INPUT_DIR}"/resources/*.jpeg 2>/dev/null | grep -q .; then
        cp "${INPUT_DIR}"/resources/*.jpeg "$RESOURCES_DIR/" 2>/dev/null
        echo "   Скопированы jpeg файлы"
    fi
    
    # Копируем gif файлы
    if ls "${INPUT_DIR}"/resources/*.gif 2>/dev/null | grep -q .; then
        cp "${INPUT_DIR}"/resources/*.gif "$RESOURCES_DIR/" 2>/dev/null
        echo "   Скопированы gif файлы"
    fi
    
    # Копируем svg файлы (если есть статичные)
    if ls "${INPUT_DIR}"/resources/*.svg 2>/dev/null | grep -q .; then
        cp "${INPUT_DIR}"/resources/*.svg "$RESOURCES_DIR/" 2>/dev/null
        echo "   Скопированы svg файлы"
    fi
    
    echo -e "${GREEN}✅ Изображения скопированы${NC}"
else
    echo -e "${BLUE}ℹ️  Папка resources не найдена${NC}"
fi

# Копируем исходный файл во временный
echo -e "${BLUE}📋 Создаём временную копию${NC}"
cp "$INPUT_FILE" "$TEMP_FILE"

# Заменяем theme в front matter на выбранную тему
echo -e "${BLUE}🎨 Обновляем тему в front matter${NC}"
sed -i '' "s/^theme: .*/theme: $THEME_NAME/" "$TEMP_FILE"

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
    
    # Сначала очищаем старые диаграммы для этого файла
    echo -e "${BLUE}🧹 Очищаем старые диаграммы${NC}"
    rm -f "${RESOURCES_DIR}/${INPUT_NAME}_diagram_"*.svg
    rm -f "${RESOURCES_DIR}/${INPUT_NAME}_diagram_"*.png
    
    # Счётчик для диаграмм
    COUNTER=1
    
    # Обрабатываем каждый mermaid блок
    # Используем временный маркер для отслеживания обработанных блоков
    while grep -q '```mermaid' "$TEMP_FILE"; do
        echo -e "${BLUE}   📊 Обрабатываем диаграмму #${COUNTER}${NC}"
        
        # Извлекаем первый необработанный mermaid блок
        awk '/```mermaid/{flag=1; next} /```/{if(flag) exit} flag' "$TEMP_FILE" > "temp_diagram_${COUNTER}.mmd"
        
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
        
        # Для PPTX и PDF используем PNG, для HTML - SVG
        if [[ "$FORMAT" == "pptx" ]] || [[ "$FORMAT" == "pdf" ]]; then
            IMAGE_EXT="png"
            OUTPUT_FORMAT="--outputFormat=png"
        else
            IMAGE_EXT="svg"
            OUTPUT_FORMAT=""
        fi
        
        # Имя выходного файла - СКВОЗНАЯ НУМЕРАЦИЯ БЕЗ ТИПА
        IMAGE_FILENAME="${INPUT_NAME}_diagram_${COUNTER}.${IMAGE_EXT}"
        IMAGE_PATH="${RESOURCES_DIR}/${IMAGE_FILENAME}"
        
        # Относительный путь для вставки в Markdown
        # Для HTML нужен путь относительно generated/, для PDF/PPTX - относительно исходного файла
        if [[ "$FORMAT" == "html" ]]; then
            IMAGE_RELATIVE_PATH="resources/${IMAGE_FILENAME}"
        else
            IMAGE_RELATIVE_PATH="generated/resources/${IMAGE_FILENAME}"
        fi
        
        echo "      Путь в Markdown: $IMAGE_RELATIVE_PATH"
        
        # Генерируем изображение с помощью mermaid-cli
        echo "      Генерируем: $IMAGE_PATH"
        
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
            echo -e "${RED}❌ Ошибка при генерации диаграммы #${COUNTER}${NC}"
            exit 1
        }
        
        # ВРЕМЕННО ОТКЛЮЧЕНО: добавление отступов для PDF
        # Проблема была в лишних строках текста на слайдах с page_image
        # if [[ "$FORMAT" == "pdf" ]]; then
        #     # Код добавления padding временно отключен
        # fi
        
        # Определяем ширину для разных форматов и типов диаграмм
        if [[ "$DIAGRAM_TYPE" == "_vertical" ]]; then
            PDF_WIDTH="700px"
            PPTX_WIDTH="750px"
        else
            PDF_WIDTH="850px"
            PPTX_WIDTH="900px"
        fi
        
        # Заменяем mermaid блок на изображение с центрированием
        # Используем разный подход для каждого формата
        case "$FORMAT" in
            "pdf")
                # Для PDF используем простой Markdown
                # Экранируем пробелы в пути для корректной работы с PDF
                ESCAPED_PATH=$(echo "$IMAGE_RELATIVE_PATH" | sed 's/ /%20/g')
                # Используем awk для замены первого блока mermaid
                awk -v img_path="$ESCAPED_PATH" '
                    BEGIN { in_block = 0; replaced = 0 }
                    /```mermaid/ && !replaced {
                        print ""
                        print ""
                        printf "![](%s)\n", img_path
                        print ""
                        print ""
                        in_block = 1
                        replaced = 1
                        next
                    }
                    /```/ && in_block {
                        in_block = 0
                        next
                    }
                    !in_block { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
            "pptx")
                # Для PPTX используем простой Markdown без стилей
                # PPTX должен центрировать изображения по умолчанию
                # Экранируем пробелы в пути
                ESCAPED_PATH=$(echo "$IMAGE_RELATIVE_PATH" | sed 's/ /%20/g')
                # Используем awk для замены первого блока mermaid
                awk -v img_path="$ESCAPED_PATH" '
                    BEGIN { in_block = 0; replaced = 0 }
                    /```mermaid/ && !replaced {
                        print ""
                        print ""
                        printf "![](%s)\n", img_path
                        print ""
                        print ""
                        in_block = 1
                        replaced = 1
                        next
                    }
                    /```/ && in_block {
                        in_block = 0
                        next
                    }
                    !in_block { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
            "html")
                # Для HTML используем div с flex
                # Используем awk для замены первого блока mermaid
                awk -v img_path="$IMAGE_RELATIVE_PATH" '
                    BEGIN { in_block = 0; replaced = 0 }
                    /```mermaid/ && !replaced {
                        print "<div style=\"display: flex; justify-content: center; align-items: center; width: 100%; height: 100%;\">"
                        printf "  <img src=\"%s\" style=\"max-width: 90%%; max-height: 380px;\" />\n", img_path
                        print "</div>"
                        in_block = 1
                        replaced = 1
                        next
                    }
                    /```/ && in_block {
                        in_block = 0
                        next
                    }
                    !in_block { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
        esac
        
        mv "temp_output.md" "$TEMP_FILE"
        rm "temp_diagram_${COUNTER}.mmd"
        
        ((COUNTER++))
    done
    
    echo -e "${GREEN}✅ Обработано диаграмм: $((COUNTER-1))${NC}"
else
    echo -e "${BLUE}ℹ️  Mermaid диаграммы не найдены${NC}"
fi

# Проверяем наличие gnuplot блоков
if grep -q '```gnuplot' "$TEMP_FILE"; then
    echo -e "${BLUE}🔍 Найдены Gnuplot графики${NC}"
    
    # Проверяем установлен ли gnuplot
    if ! command -v gnuplot &> /dev/null; then
        echo -e "${RED}❌ Ошибка: gnuplot не установлен${NC}"
        echo "   Установите его командой: brew install gnuplot"
        exit 1
    fi
    
    # Сначала очищаем старые графики для этого файла
    echo -e "${BLUE}🧹 Очищаем старые графики${NC}"
    rm -f "${RESOURCES_DIR}/${INPUT_NAME}_plot_"*.png
    
    # Счётчик для графиков
    PLOT_COUNTER=1
    
    # Обрабатываем каждый gnuplot блок
    while grep -q '```gnuplot' "$TEMP_FILE"; do
        echo -e "${BLUE}   📊 Обрабатываем график #${PLOT_COUNTER}${NC}"
        
        # Извлекаем первый gnuplot блок
        awk '/```gnuplot/{flag=1; next} /```/{if(flag) exit} flag' "$TEMP_FILE" > "temp_plot_${PLOT_COUNTER}.plt"
        
        # Имя выходного файла PNG
        PNG_FILENAME="${INPUT_NAME}_plot_${PLOT_COUNTER}.png"
        PNG_PATH="${RESOURCES_DIR}/${PNG_FILENAME}"
        
        # Относительный путь для вставки в Markdown
        if [[ "$FORMAT" == "html" ]]; then
            PNG_RELATIVE_PATH="resources/${PNG_FILENAME}"
        else
            PNG_RELATIVE_PATH="generated/resources/${PNG_FILENAME}"
        fi
        
        echo "      Путь в Markdown: $PNG_RELATIVE_PATH"
        echo "      Генерируем: $PNG_PATH"
        
        # Создаём временный gnuplot скрипт с настройками PNG
        GNUPLOT_SCRIPT="temp_plot_${PLOT_COUNTER}_full.plt"
        cat > "$GNUPLOT_SCRIPT" << EOF
# Настройки для PNG терминала
set terminal png enhanced size 800,600 font "Arial,12" background rgb "white"
set output "${PNG_PATH}"

# Стандартные настройки для чистого вида
set border linewidth 1.5
set grid
set key outside right top

# Загружаем пользовательский код
EOF
        cat "temp_plot_${PLOT_COUNTER}.plt" >> "$GNUPLOT_SCRIPT"
        
        # Генерируем PNG с помощью gnuplot
        gnuplot "$GNUPLOT_SCRIPT" || {
            echo -e "${RED}❌ Ошибка при генерации PNG для графика #${PLOT_COUNTER}${NC}"
            exit 1
        }
        
        # Для PDF добавляем небольшой фиксированный отступ от заголовка
        if [[ "$FORMAT" == "pdf" ]]; then
            if command -v magick &> /dev/null; then
                # Фиксированный небольшой отступ
                PADDING=30
                echo "      Добавляем минимальный отступ для графика (${PADDING}px)..."
                magick "$PNG_PATH" -gravity North -background transparent -splice 0x${PADDING} "$PNG_PATH" || {
                    echo -e "${RED}❌ Ошибка при добавлении отступа${NC}"
                }
            elif command -v convert &> /dev/null; then
                # Для старой версии ImageMagick
                PADDING=30
                echo "      Добавляем минимальный отступ для графика (${PADDING}px)..."
                convert "$PNG_PATH" -gravity North -background transparent -splice 0x${PADDING} "$PNG_PATH" || {
                    echo -e "${RED}❌ Ошибка при добавлении отступа${NC}"
                }
            fi
        fi
        
        # Заменяем gnuplot блок на изображение с центрированием
        case "$FORMAT" in
            "pdf")
                # Для PDF используем простой Markdown
                ESCAPED_PATH=$(echo "$PNG_RELATIVE_PATH" | sed 's/ /%20/g')
                # Используем awk для замены первого блока gnuplot
                awk -v img_path="$ESCAPED_PATH" '
                    BEGIN { in_block = 0; replaced = 0 }
                    /```gnuplot/ && !replaced {
                        print ""
                        print ""
                        printf "![График](%s)\n", img_path
                        print ""
                        print ""
                        in_block = 1
                        replaced = 1
                        next
                    }
                    /```/ && in_block {
                        in_block = 0
                        next
                    }
                    !in_block { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
            "pptx")
                # Для PPTX используем простой Markdown
                ESCAPED_PATH=$(echo "$PNG_RELATIVE_PATH" | sed 's/ /%20/g')
                # Используем awk для замены первого блока gnuplot
                awk -v img_path="$ESCAPED_PATH" '
                    BEGIN { in_block = 0; replaced = 0 }
                    /```gnuplot/ && !replaced {
                        print ""
                        print ""
                        printf "![График](%s)\n", img_path
                        print ""
                        print ""
                        in_block = 1
                        replaced = 1
                        next
                    }
                    /```/ && in_block {
                        in_block = 0
                        next
                    }
                    !in_block { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
            "html")
                # Для HTML используем div с flex
                # Используем awk для замены первого блока gnuplot
                awk -v img_path="$PNG_RELATIVE_PATH" '
                    BEGIN { in_block = 0; replaced = 0 }
                    /```gnuplot/ && !replaced {
                        print "<div style=\"display: flex; justify-content: center; align-items: center; width: 100%; height: 100%;\">"
                        printf "  <img src=\"%s\" style=\"max-width: 90%%; max-height: 380px;\" />\n", img_path
                        print "</div>"
                        in_block = 1
                        replaced = 1
                        next
                    }
                    /```/ && in_block {
                        in_block = 0
                        next
                    }
                    !in_block { print }
                ' "$TEMP_FILE" > "temp_output.md"
                ;;
        esac
        
        mv "temp_output.md" "$TEMP_FILE"
        rm "temp_plot_${PLOT_COUNTER}.plt" "$GNUPLOT_SCRIPT"
        
        ((PLOT_COUNTER++))
    done
    
    echo -e "${GREEN}✅ Обработано графиков: $((PLOT_COUNTER-1))${NC}"
else
    echo -e "${BLUE}ℹ️  Gnuplot графики не найдены${NC}"
fi

# Проверяем наличие промптов СОЗДАТЬ ИЗОБРАЖЕНИЕ:
if grep -q '<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ:' "$TEMP_FILE"; then
    echo -e "${BLUE}🔍 Найдены промпты для генерации изображений${NC}"

    # Загружаем ключ OpenAI
    OPENAI_API_KEY=""
    if [ -f "/Users/dzolotov/mcp/obsidian/obsidian-mcp-server/.env" ]; then
        OPENAI_API_KEY=$(grep "OPENAI_API_KEY=" "/Users/dzolotov/mcp/obsidian/obsidian-mcp-server/.env" | cut -d'=' -f2)
        echo -e "${BLUE}📝 Загружен ключ OpenAI${NC}"
    else
        echo -e "${RED}❌ Ошибка: файл с ключом OpenAI не найден${NC}"
        echo "   Ожидаемый путь: /Users/dzolotov/mcp/obsidian/obsidian-mcp-server/.env"
        exit 1
    fi

    # Создаём папку resources если её нет
    mkdir -p "$STATIC_RESOURCES_DIR"

    # Определяем стартовый номер для новых изображений
    # Ищем все существующие изображения (любые суффиксы) и находим максимальный номер
    MAX_IMAGE_NUMBER=0
    for img_file in "${STATIC_RESOURCES_DIR}/${INPUT_NAME}_image_"*.png; do
        if [ -f "$img_file" ]; then
            # Извлекаем номер из имени файла (учитываем возможные суффиксы _original, _withtext)
            IMAGE_NUM=$(basename "$img_file" .png | sed 's/.*_image_\([0-9][0-9]*\).*/\1/')
            if [[ "$IMAGE_NUM" =~ ^[0-9]+$ ]] && [ "$IMAGE_NUM" -gt "$MAX_IMAGE_NUMBER" ]; then
                MAX_IMAGE_NUMBER=$IMAGE_NUM
            fi
        fi
    done

    if [ "$MAX_IMAGE_NUMBER" -gt 0 ]; then
        IMAGE_COUNTER=$((MAX_IMAGE_NUMBER + 1))
        echo -e "${BLUE}📸 Найдено изображений до номера $MAX_IMAGE_NUMBER, следующий номер: $IMAGE_COUNTER${NC}"
    else
        IMAGE_COUNTER=1
        echo -e "${BLUE}🆕 Создаём новые изображения${NC}"
    fi

    # Функция для обработки команд ДОБАВИТЬ ТЕКСТ
    process_text_overlays_for_current_image() {
        local CURRENT_LINE_NUM="$1"


        # Проверяем наличие Python3
        if ! command -v python3 &> /dev/null; then
            echo "      ⚠️ Python3 не найден, пропускаем наложение текста"
            return
        fi

        local TEXT_COUNTER=1
        local LAST_PROCESSED_IMAGE=""

        # Ищем команды ДОБАВИТЬ ТЕКСТ сразу после текущей строки
        for i in {1..10}; do
            local CHECK_LINE=$((CURRENT_LINE_NUM + i))
            local LINE_CONTENT=$(sed -n "${CHECK_LINE}p" "$TEMP_FILE")

            # Если встретили следующее изображение или конец - выходим
            if echo "$LINE_CONTENT" | grep -q "<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ\|<!-- ОБРАБОТАНО ИЗОБРАЖЕНИЕ"; then
                break
            fi

            # Если нашли команду добавления текста
            if echo "$LINE_CONTENT" | grep -q "<!-- ДОБАВИТЬ ТЕКСТ В"; then
                echo "   ✍️ Обрабатываем текстовое наложение #${TEXT_COUNTER}"

                # Парсим команду
                local X_POS=$(echo "$LINE_CONTENT" | sed 's/.*(\([^,]*\),.*/\1/' | tr -d ' ')
                local Y_POS=$(echo "$LINE_CONTENT" | sed 's/.*,\s*\([^)]*\)).*/\1/' | tr -d ' ')
                local TEXT_CONTENT=$(echo "$LINE_CONTENT" | sed 's/.*: *\(.*\) *-->.*/\1/')
                local FONT_SIZE="72"

                if echo "$LINE_CONTENT" | grep -q "РАЗМЕР"; then
                    FONT_SIZE=$(echo "$LINE_CONTENT" | sed 's/.*РАЗМЕР \([0-9]*\).*/\1/')
                    TEXT_CONTENT=$(echo "$LINE_CONTENT" | sed 's/.*РАЗМЕР [0-9]*: *\(.*\) *-->.*/\1/')
                fi

            echo "      Позиция: X=$X_POS, Y=$Y_POS"
            echo "      Текст: $TEXT_CONTENT"
            echo "      Размер шрифта: $FONT_SIZE"

                # Находим изображение перед текущей позицией
                local INLINE_IMAGE_PATH=""
                for j in {1..10}; do
                    local IMG_CHECK_LINE=$((CURRENT_LINE_NUM - j))
                    if [ $IMG_CHECK_LINE -gt 0 ]; then
                        local IMG_LINE_CONTENT=$(sed -n "${IMG_CHECK_LINE}p" "$TEMP_FILE")
                        if echo "$IMG_LINE_CONTENT" | grep -q "!\[\]"; then
                            INLINE_IMAGE_PATH=$(echo "$IMG_LINE_CONTENT" | sed 's/.*!\[\](\(.*\)).*/\1/')
                            break
                        fi
                    fi
                done

            if [ -n "$INLINE_IMAGE_PATH" ]; then
                local LAST_IMAGE="${STATIC_RESOURCES_DIR}/${INLINE_IMAGE_PATH#resources/}"
                local BASE_IMAGE="${LAST_IMAGE/_withtext.png/.png}"
                BASE_IMAGE="${BASE_IMAGE/_original.png/.png}"
                local ORIGINAL_IMAGE="${BASE_IMAGE/.png/_original.png}"
                local PREV_WITHTEXT_IMAGE="${BASE_IMAGE/.png/_withtext.png}"

                # Выбираем источник
                local SOURCE_IMAGE
                if [ "$BASE_IMAGE" != "$LAST_PROCESSED_IMAGE" ]; then
                    if [ -f "$ORIGINAL_IMAGE" ]; then
                        SOURCE_IMAGE="$ORIGINAL_IMAGE"
                        echo "      Используем оригинал: $(basename "$ORIGINAL_IMAGE")"
                    else
                        echo "      ⚠️ Оригинал не найден: $ORIGINAL_IMAGE"
                        continue
                    fi
                    LAST_PROCESSED_IMAGE="$BASE_IMAGE"
                elif [ -f "$PREV_WITHTEXT_IMAGE" ]; then
                    SOURCE_IMAGE="$PREV_WITHTEXT_IMAGE"
                    echo "      Используем withtext: $(basename "$PREV_WITHTEXT_IMAGE")"
                else
                    SOURCE_IMAGE="$ORIGINAL_IMAGE"
                    echo "      Используем оригинал: $(basename "$ORIGINAL_IMAGE")"
                fi

                local WITHTEXT_IMAGE="${BASE_IMAGE/.png/_withtext.png}"
                echo "      Создается: $(basename "$WITHTEXT_IMAGE")"

                # Создаем Python скрипт для наложения текста
                python3 -c "
from PIL import Image, ImageDraw, ImageFont
import sys

try:
    img = Image.open('$SOURCE_IMAGE')
    if '$SOURCE_IMAGE' != '$WITHTEXT_IMAGE':
        img.save('$WITHTEXT_IMAGE')
        img = Image.open('$WITHTEXT_IMAGE')

    width, height = img.size
    draw = ImageDraw.Draw(img)

    font_size = int('$FONT_SIZE')
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Arial.ttf', font_size)
    except:
        font = ImageFont.load_default()

    text = '$TEXT_CONTENT'
    x_pos = float('$X_POS')
    y_pos = float('$Y_POS')

    center_x, center_y = width // 2, height // 2

    if font:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
    else:
        text_width = len(text) * 10
        text_height = 20

    final_x = center_x + (x_pos * width // 2) - (text_width // 2)
    final_y = center_y + (y_pos * height // 2) - (text_height // 2)

    final_x = max(10, min(final_x, width - text_width - 10))
    final_y = max(10, min(final_y, height - text_height - 10))

    # Определяем контрастный цвет
    region = img.crop((final_x, final_y, final_x + text_width, final_y + text_height))
    total_brightness = 0
    pixel_count = 0
    for pixel in region.getdata():
        if len(pixel) >= 3:
            brightness = pixel[0] * 0.299 + pixel[1] * 0.587 + pixel[2] * 0.114
            total_brightness += brightness
            pixel_count += 1

    avg_brightness = total_brightness / pixel_count if pixel_count > 0 else 128
    text_color = 'white' if avg_brightness < 128 else 'black'
    outline_color = 'black' if avg_brightness < 128 else 'white'

    # Рисуем текст с обводкой
    if font:
        for dx in [-2, -1, 0, 1, 2]:
            for dy in [-2, -1, 0, 1, 2]:
                if dx != 0 or dy != 0:
                    draw.text((final_x + dx, final_y + dy), text, font=font, fill=outline_color)
        draw.text((final_x, final_y), text, font=font, fill=text_color)
    else:
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                if dx != 0 or dy != 0:
                    draw.text((final_x + dx, final_y + dy), text, fill=outline_color)
        draw.text((final_x, final_y), text, fill=text_color)

    img.save('$WITHTEXT_IMAGE')
    print(f'Текст добавлен: $WITHTEXT_IMAGE')

except Exception as e:
    print(f'Ошибка: {e}')
    sys.exit(1)
"

                # Обновляем ссылку в исходном файле
                if [ -f "$WITHTEXT_IMAGE" ]; then
                    local WITHTEXT_RELATIVE="resources/$(basename "$WITHTEXT_IMAGE")"
                    local ORIGINAL_RELATIVE="$INLINE_IMAGE_PATH"

                    sed -i.bak "s|!\\[\\]($ORIGINAL_RELATIVE)|![]($WITHTEXT_RELATIVE)|g" "$INPUT_FILE"
                    rm -f "$INPUT_FILE.bak"
                    echo "      Обновлена ссылка: $WITHTEXT_RELATIVE"
                fi
            fi

                # Помечаем команду как обработанную
                awk '
                    BEGIN { replaced = 0 }
                    /<!-- ДОБАВИТЬ ТЕКСТ В/ && !replaced {
                        gsub(/<!-- ДОБАВИТЬ ТЕКСТ В/, "<!-- ОБРАБОТАНО ТЕКСТ В")
                        print $0
                        replaced = 1
                        next
                    }
                    { print }
                ' "$TEMP_FILE" > "temp_output.md"
                mv "temp_output.md" "$TEMP_FILE"

                TEXT_COUNTER=$((TEXT_COUNTER + 1))
            fi
        done
    }

    # Обрабатываем каждый промпт
    while grep -q '<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ:' "$TEMP_FILE"; do
        echo -e "${BLUE}   🎨 Генерируем изображение #${IMAGE_COUNTER}${NC}"

        # Извлекаем промпт из первого найденного комментария
        ORIGINAL_PROMPT=$(grep -m1 '<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ:' "$TEMP_FILE" | sed 's/<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: *//; s/ *-->.*$//')

        # Добавляем инструкцию для проверки текста к промпту
        PROMPT="${ORIGINAL_PROMPT}. Make sure any text in the image is spelled correctly and grammatically correct. Double-check all text elements for accuracy."
        echo "      Оригинальный промпт: $ORIGINAL_PROMPT"
        echo "      Расширенный промпт: $PROMPT"

        # Определяем номер изображения: ищем inline ссылку ПРЯМО перед комментарием
        # Получаем номер строки текущего комментария СОЗДАТЬ ИЗОБРАЖЕНИЕ
        # Используем фиксированный поиск вместо regex для избежания проблем с экранированием
        CURRENT_COMMENT_LINE=$(LC_ALL=C.UTF-8 grep -n -F "<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: ${ORIGINAL_PROMPT}" "$TEMP_FILE" | head -1 | cut -d: -f1)

        # Ищем inline ссылку в строках непосредственно перед комментарием (в пределах 3 строк)
        if [ -n "$CURRENT_COMMENT_LINE" ]; then
            PREV_LINES_START=$((CURRENT_COMMENT_LINE - 3))
            PREV_LINES_END=$((CURRENT_COMMENT_LINE - 1))
            if [ $PREV_LINES_START -lt 1 ]; then
                PREV_LINES_START=1
            fi

            # Ищем inline изображение в предыдущих строках (ближайшую к комментарию)
            PRECEDING_IMAGE=$(sed -n "${PREV_LINES_START},${PREV_LINES_END}p" "$TEMP_FILE" | grep '!\[\](' | tail -1 | sed 's/.*!\[\](\(.*\)).*/\1/')

            if [ -n "$PRECEDING_IMAGE" ]; then
                # Если есть предшествующая ссылка, значит это изображение уже было обработано
                echo "      ⏭️  Найдена предшествующая ссылка: $PRECEDING_IMAGE - изображение уже обработано, пропускаем"

                # НО ВАЖНО: заменяем СОЗДАТЬ на ОБРАБОТАНО чтобы цикл мог продолжиться
                # И В TEMP_FILE И В INPUT_FILE!
                CURRENT_LINE_TO_MARK=$(LC_ALL=C.UTF-8 grep -n -F "<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: ${ORIGINAL_PROMPT}" "$TEMP_FILE" | head -1 | cut -d: -f1)
                if [ -n "$CURRENT_LINE_TO_MARK" ]; then
                    LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 sed -i.bak "${CURRENT_LINE_TO_MARK}s/СОЗДАТЬ ИЗОБРАЖЕНИЕ/ОБРАБОТАНО ИЗОБРАЖЕНИЕ/" "$TEMP_FILE"
                    rm -f "$TEMP_FILE.bak"
                    echo "      ✅ Заменено СОЗДАТЬ на ОБРАБОТАНО в TEMP_FILE для пропуска"
                fi

                # ТАКЖЕ заменяем в оригинальном файле
                CURRENT_LINE_ORIG_SKIP=$(LC_ALL=C.UTF-8 grep -n -F "<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: ${ORIGINAL_PROMPT}" "$INPUT_FILE" | head -1 | cut -d: -f1)
                if [ -n "$CURRENT_LINE_ORIG_SKIP" ]; then
                    LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 sed -i.bak "${CURRENT_LINE_ORIG_SKIP}s/СОЗДАТЬ ИЗОБРАЖЕНИЕ/ОБРАБОТАНО ИЗОБРАЖЕНИЕ/" "$INPUT_FILE"
                    rm -f "$INPUT_FILE.bak"
                    echo "      ✅ Заменено СОЗДАТЬ на ОБРАБОТАНО в INPUT_FILE для пропуска"
                fi

                continue
            else
                echo "      📋 Inline ссылка перед комментарием не найдена, используем следующий номер: $IMAGE_COUNTER"
            fi
        fi

        # Имя выходного файла PNG - сохраняем в постоянную папку resources
        IMAGE_FILENAME="${INPUT_NAME}_image_${IMAGE_COUNTER}.png"
        IMAGE_PATH="${STATIC_RESOURCES_DIR}/${IMAGE_FILENAME}"

        # Создаём папку resources если её нет
        mkdir -p "$STATIC_RESOURCES_DIR"

        # Относительный путь для вставки в Markdown (всегда resources/)
        IMAGE_RELATIVE_PATH="resources/${IMAGE_FILENAME}"

        echo "      Путь в Markdown: $IMAGE_RELATIVE_PATH"

        # Проверяем, существует ли уже оригинал для этого изображения
        ORIGINAL_IMAGE_PATH="${IMAGE_PATH/.png/_original.png}"
        if [ -f "$ORIGINAL_IMAGE_PATH" ]; then
            echo "      ⚠️  Изображение уже существует: $ORIGINAL_IMAGE_PATH - пропускаем генерацию"
            # Пропускаем генерацию, но продолжаем обработку (обновление маркдауна)
        else
            # Если есть команда СОЗДАТЬ ИЗОБРАЖЕНИЕ - генерируем
            echo "      Генерируем: $IMAGE_PATH"

            # Создаём временный Python скрипт для генерации изображения
        DALLE_SCRIPT="temp_dalle_${IMAGE_COUNTER}.py"

        # Экранируем промпт для безопасной передачи в Python
        ESCAPED_PROMPT=$(printf '%s\n' "$PROMPT" | sed "s/'/\\\\'/g")

        cat > "$DALLE_SCRIPT" << EOF
import requests
import json
import urllib.request
import os

api_key = "${OPENAI_API_KEY}"
prompt = '''${ESCAPED_PROMPT}'''
output_path = "${IMAGE_PATH}"

# Запрос к OpenAI DALL-E API
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

# Пробуем gpt-image-1, если не работает - fallback на dall-e-3
try_gpt_image_1 = True

if try_gpt_image_1:
    data = {
        "model": "gpt-image-1",
        "prompt": prompt,
        "n": 1,
        "size": "1536x1024",
        "quality": "high"
    }
else:
    data = {
        "model": "dall-e-3",
        "prompt": prompt,
        "n": 1,
        "size": "1792x1024",
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

    if data["model"] == "gpt-image-1":
        # gpt-image-1 возвращает base64
        image_b64 = result["data"][0]["b64_json"]
        import base64
        image_data = base64.b64decode(image_b64)
        with open(output_path, 'wb') as f:
            f.write(image_data)
    else:
        # dall-e-3 возвращает URL
        image_url = result["data"][0]["url"]
        urllib.request.urlretrieve(image_url, output_path)

except Exception as e:
    if "403" in str(e) and try_gpt_image_1:
        print("GPT Image 1 недоступен, используем DALL-E 3...")
        # Fallback на DALL-E 3
        data = {
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1792x1024",
            "quality": "standard",
            "style": "natural"
        }

        response = requests.post(
            "https://api.openai.com/v1/images/generations",
            headers=headers,
            json=data
        )
        response.raise_for_status()

        result = response.json()
        image_url = result["data"][0]["url"]
        urllib.request.urlretrieve(image_url, output_path)
    else:
        print(f"⚠️  Ошибка при генерации изображения: {e}")
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_details = e.response.json()
                print(f"Детали ошибки: {error_details}")
            except:
                print(f"Ответ сервера: {e.response.text}")
        print("⏭️  Пропускаем это изображение и продолжаем...")
        exit(0)

    # Сохраняем также оригинальную копию без надписей
    original_path = output_path.replace('.png', '_original.png')
    import shutil
    shutil.copy2(output_path, original_path)

    print(f"Изображение сохранено: {output_path}")
    print(f"Оригинал сохранен: {original_path}")

except Exception as e:
    print(f"⚠️  Ошибка при генерации изображения: {e}")
    if hasattr(e, 'response') and e.response is not None:
        try:
            error_details = e.response.json()
            print(f"Детали ошибки: {error_details}")
        except:
            print(f"Ответ сервера: {e.response.text}")
    print("⏭️  Пропускаем это изображение и продолжаем...")
    exit(0)
EOF

            # Генерируем изображение с помощью Python
            if command -v python3 &> /dev/null; then
                python3 "$DALLE_SCRIPT" || {
                    echo -e "${YELLOW}⚠️  Предупреждение: ошибка при генерации изображения #${IMAGE_COUNTER}, пропускаем${NC}"
                }
            elif command -v python &> /dev/null; then
                python "$DALLE_SCRIPT" || {
                    echo -e "${YELLOW}⚠️  Предупреждение: ошибка при генерации изображения #${IMAGE_COUNTER}, пропускаем${NC}"
                }
            else
                echo -e "${YELLOW}⚠️  Предупреждение: Python не найден, пропускаем генерацию изображения #${IMAGE_COUNTER}${NC}"
            fi

            rm "$DALLE_SCRIPT"

            # Сразу создаем копию оригинала без текста (только если файл был создан)
            # ORIGINAL_IMAGE_PATH уже определен выше
            if [ -f "$IMAGE_PATH" ]; then
                cp "$IMAGE_PATH" "$ORIGINAL_IMAGE_PATH"
                echo "      Оригинал сохранен: $ORIGINAL_IMAGE_PATH"

                # Удаляем промежуточный файл, оставляем только _original
                rm "$IMAGE_PATH"
                echo "      Удален промежуточный файл: $IMAGE_PATH"
            else
                echo -e "${YELLOW}      ⚠️  Изображение не было создано, пропускаем сохранение оригинала${NC}"
            fi
        fi

        # Заменяем СОЗДАТЬ на ОБРАБОТАНО в TEMP_FILE (для корректной работы цикла) и в INPUT_FILE (для сохранения изменений)
        echo "      🔍 Заменяем СОЗДАТЬ на ОБРАБОТАНО в обоих файлах"

        # В TEMP_FILE для продолжения цикла (с правильной локалью для UTF-8)
        # Заменяем текущий промпт (ИМЕННО этот, а не первый попавшийся) на ОБРАБОТАНО в TEMP_FILE
        FIRST_LINE_TEMP=$(LC_ALL=C.UTF-8 grep -n -F "<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: ${ORIGINAL_PROMPT}" "$TEMP_FILE" | head -1 | cut -d: -f1)
        if [ -n "$FIRST_LINE_TEMP" ]; then
            LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 sed -i.bak "${FIRST_LINE_TEMP}s/СОЗДАТЬ ИЗОБРАЖЕНИЕ/ОБРАБОТАНО ИЗОБРАЖЕНИЕ/" "$TEMP_FILE"
            rm -f "$TEMP_FILE.bak"
            echo "      ✅ Заменено СОЗДАТЬ на ОБРАБОТАНО в TEMP_FILE (строка ${FIRST_LINE_TEMP})"
        fi

        # В INPUT_FILE для сохранения изменений - СНАЧАЛА заменяем, ПОТОМ добавляем изображение
        # Ищем строку с текущим промптом (ИМЕННО этим, а не первым попавшимся) - используем фиксированный поиск
        CURRENT_LINE_ORIG=$(LC_ALL=C.UTF-8 grep -n -F "<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ: ${ORIGINAL_PROMPT}" "$INPUT_FILE" | head -1 | cut -d: -f1)

        if [ -n "$CURRENT_LINE_ORIG" ]; then
            # СНАЧАЛА заменяем конкретное вхождение СОЗДАТЬ на ОБРАБОТАНО (с правильной локалью для UTF-8)
            LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 sed -i.bak "${CURRENT_LINE_ORIG}s/СОЗДАТЬ ИЗОБРАЖЕНИЕ/ОБРАБОТАНО ИЗОБРАЖЕНИЕ/" "$INPUT_FILE"
            rm -f "$INPUT_FILE.bak"
            echo "      ✅ Заменено СОЗДАТЬ на ОБРАБОТАНО в оригинальном файле"
        fi

        case "$FORMAT" in
            "pdf"|"pptx")
                # Для PDF/PPTX используем простой Markdown
                ESCAPED_PATH=$(echo "$IMAGE_RELATIVE_PATH" | sed 's/ /%20/g')
                # Находим первое вхождение ОБРАБОТАНО (текущий промпт уже заменен выше)
                FIRST_LINE=$(grep -n '<!-- ОБРАБОТАНО ИЗОБРАЖЕНИЕ:' "$TEMP_FILE" | head -1 | cut -d: -f1)
                if [ -n "$FIRST_LINE" ]; then
                    # Добавляем изображение перед строкой с промптом
                    sed "${FIRST_LINE}i\\
\\
\\
![]($ESCAPED_PATH)\\
" "$TEMP_FILE" > "temp_output.md"
                else
                    cp "$TEMP_FILE" "temp_output.md"
                fi
                ;;
            "html")
                # Для HTML используем div с flex
                FIRST_LINE=$(grep -n '<!-- ОБРАБОТАНО ИЗОБРАЖЕНИЕ:' "$TEMP_FILE" | head -1 | cut -d: -f1)
                if [ -n "$FIRST_LINE" ]; then
                    # Добавляем изображение перед строкой с промптом
                    sed "${FIRST_LINE}i\\
<div style=\"display: flex; justify-content: center; align-items: center; width: 100%; height: 100%;\">\\
  <img src=\"$IMAGE_RELATIVE_PATH\" style=\"max-width: 90%; max-height: 380px;\" />\\
</div>\\
" "$TEMP_FILE" > "temp_output.md"
                else
                    cp "$TEMP_FILE" "temp_output.md"
                fi
                ;;
        esac

        mv "temp_output.md" "$TEMP_FILE"

        # После завершения всех изменений в файле, находим ВСЕ строки с ОБРАБОТАНО ИЗОБРАЖЕНИЕ и обрабатываем текст
        TEXT_APPLIED=false
        while read -r LINE_INFO; do
            PROCESSED_LINE=$(echo "$LINE_INFO" | cut -d: -f1)
            if [ -n "$PROCESSED_LINE" ]; then
                echo "   🔍 Проверяем команды ДОБАВИТЬ ТЕКСТ для строки $PROCESSED_LINE"
                # Проверяем команды ДОБАВИТЬ ТЕКСТ сразу после промпта этого изображения
                process_text_overlays_for_current_image "$PROCESSED_LINE"
                # Проверяем, был ли применен текст (есть ли файл _withtext)
                WITHTEXT_FILE="${IMAGE_PATH/.png/_withtext.png}"
                if [ -f "$WITHTEXT_FILE" ]; then
                    TEXT_APPLIED=true
                fi
            fi
        done < <(grep -n '<!-- ОБРАБОТАНО ИЗОБРАЖЕНИЕ:' "$TEMP_FILE")

        # Устанавливаем правильный путь в зависимости от того, был ли применен текст
        if [ "$TEXT_APPLIED" = true ]; then
            IMAGE_RELATIVE_PATH="resources/${IMAGE_FILENAME/.png/_withtext.png}"
        else
            IMAGE_RELATIVE_PATH="resources/${IMAGE_FILENAME/.png/_original.png}"
        fi
        echo "      Финальный путь в Markdown: $IMAGE_RELATIVE_PATH"

        # Теперь добавляем ссылку с правильным путем в оригинальный файл
        if [ -n "$CURRENT_LINE_ORIG" ]; then
            CURRENT_LINE_PROCESSED=$(LC_ALL=C.UTF-8 grep -n -F "<!-- ОБРАБОТАНО ИЗОБРАЖЕНИЕ: ${ORIGINAL_PROMPT}" "$INPUT_FILE" | head -1 | cut -d: -f1)
            if [ -n "$CURRENT_LINE_PROCESSED" ]; then
                LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 sed "${CURRENT_LINE_PROCESSED}i\\
\\
![](${IMAGE_RELATIVE_PATH})\\
" "$INPUT_FILE" > "temp_orig.md"
                mv "temp_orig.md" "$INPUT_FILE"
                echo "      ✅ Добавлена ссылка на изображение: $IMAGE_RELATIVE_PATH"
            fi
        fi

        ((IMAGE_COUNTER++))
    done

    echo -e "${GREEN}✅ Сгенерировано изображений: $((IMAGE_COUNTER-1))${NC}"
else
    echo -e "${BLUE}ℹ️  Промпты для генерации изображений не найдены${NC}"
fi

# Корректируем пути к изображениям и скриптам только для HTML
if [[ "$FORMAT" == "html" ]]; then
    # НОВАЯ ЛОГИКА: Сканируем файл сверху вниз и собираем все изображения с командами
    echo -e "${BLUE}✍️ Сканируем файл для поиска изображений и команд наложения текста${NC}"

    if command -v python3 &> /dev/null; then
        # Массивы для хранения информации об изображениях
        declare -a IMAGE_PATHS=()
        declare -a TEXT_COMMANDS=()

        CURRENT_LINE=1
        TOTAL_LINES=$(wc -l < "$INPUT_FILE")
        CURRENT_IMAGE_PATH=""

        while [ $CURRENT_LINE -le $TOTAL_LINES ]; do
            LINE_CONTENT=$(sed -n "${CURRENT_LINE}p" "$INPUT_FILE")

            # Проверяем на ссылку изображения
            if echo "$LINE_CONTENT" | grep -q "^!\[.*\](.*\.png)"; then
                CURRENT_IMAGE_PATH=$(echo "$LINE_CONTENT" | sed 's/^!\[.*\](\([^)]*\))/\1/')
                echo "   🖼️ Найдено изображение на строке $CURRENT_LINE: $CURRENT_IMAGE_PATH"

                # Ищем команды ДОБАВИТЬ ТЕКСТ для этого изображения (в следующих 10 строках)
                for i in {1..10}; do
                    CHECK_LINE=$((CURRENT_LINE + i))
                    if [ $CHECK_LINE -gt $TOTAL_LINES ]; then
                        break
                    fi

                    CHECK_CONTENT=$(sed -n "${CHECK_LINE}p" "$INPUT_FILE")

                    # Если встретили следующее изображение - выходим
                    if echo "$CHECK_CONTENT" | grep -q "^!\[.*\](.*\.png)"; then
                        break
                    fi

                    # Если нашли команду ДОБАВИТЬ ТЕКСТ
                    if echo "$CHECK_CONTENT" | grep -q "<!-- ДОБАВИТЬ ТЕКСТ В"; then
                        echo "      ✍️ Найдена команда наложения текста на строке $CHECK_LINE"

                        # Парсим команду
                        X_POS=$(echo "$CHECK_CONTENT" | sed 's/.*(\([^,]*\),.*/\1/' | tr -d ' ')
                        Y_POS=$(echo "$CHECK_CONTENT" | sed 's/.*,\s*\([^)]*\)).*/\1/' | tr -d ' ')
                        TEXT_CONTENT=$(echo "$CHECK_CONTENT" | sed 's/.*: *\(.*\) *-->.*/\1/')
                        FONT_SIZE="72"

                        if echo "$CHECK_CONTENT" | grep -q "РАЗМЕР"; then
                            FONT_SIZE=$(echo "$CHECK_CONTENT" | sed 's/.*РАЗМЕР \([0-9]*\).*/\1/')
                            TEXT_CONTENT=$(echo "$CHECK_CONTENT" | sed 's/.*РАЗМЕР [0-9]*: *\(.*\) *-->.*/\1/')
                        fi

                        echo "         Позиция: ($X_POS, $Y_POS), Текст: '$TEXT_CONTENT', Размер: $FONT_SIZE"

                        # Применяем текст к изображению
                        if [ -n "$CURRENT_IMAGE_PATH" ]; then
                            # Определяем полный путь к изображению
                            if [[ "$CURRENT_IMAGE_PATH" == resources/* ]]; then
                                # Используем рабочую директорию, а не SCRIPT_DIR
                                FULL_IMAGE_PATH="$CURRENT_IMAGE_PATH"
                            else
                                FULL_IMAGE_PATH="$CURRENT_IMAGE_PATH"
                            fi

                            if [ -f "$FULL_IMAGE_PATH" ]; then
                                # Создаем версию с текстом
                                WITHTEXT_IMAGE="${FULL_IMAGE_PATH%.*}_withtext.png"

                                echo "         🎨 Применяем текст к изображению: $FULL_IMAGE_PATH"

                                # Создаем Python скрипт для наложения текста
                                python3 << EOF
from PIL import Image, ImageDraw, ImageFont
import sys

try:
    img = Image.open('$FULL_IMAGE_PATH')
    width, height = img.size

    # Создаем объект для рисования
    draw = ImageDraw.Draw(img)

    # Пытаемся найти шрифт
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Arial.ttf', $FONT_SIZE)
    except:
        try:
            font = ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf', $FONT_SIZE)
        except:
            font = ImageFont.load_default()

    # Преобразуем координаты из диапазона [-1, 1] в пиксели
    x = int((float('$X_POS') + 1) * width / 2)
    y = int((float('$Y_POS') + 1) * height / 2)

    # Получаем размер текста
    bbox = draw.textbbox((0, 0), '$TEXT_CONTENT', font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Центрируем текст
    x = x - text_width // 2
    y = y - text_height // 2

    # Рисуем текст с контуром
    outline_width = 3
    for adj_x in range(-outline_width, outline_width + 1):
        for adj_y in range(-outline_width, outline_width + 1):
            if adj_x != 0 or adj_y != 0:
                draw.text((x + adj_x, y + adj_y), '$TEXT_CONTENT', font=font, fill='black')

    # Рисуем основной текст
    draw.text((x, y), '$TEXT_CONTENT', font=font, fill='white')

    # Сохраняем с суффиксом _withtext
    img.save('$WITHTEXT_IMAGE')
    print(f"✅ Текст наложен: $WITHTEXT_IMAGE")

except Exception as e:
    print(f"❌ Ошибка: {e}")
    sys.exit(1)
EOF

                                # Заменяем ссылку на изображение в файле
                                if [ -f "$WITHTEXT_IMAGE" ]; then
                                    WITHTEXT_RELATIVE=$(echo "$WITHTEXT_IMAGE" | sed "s|$SCRIPT_DIR/../||")
                                    sed -i.bak "${CURRENT_LINE}s|$CURRENT_IMAGE_PATH|$WITHTEXT_RELATIVE|" "$INPUT_FILE"
                                    rm -f "$INPUT_FILE.bak"
                                    echo "         ✅ Заменена ссылка на изображение с текстом"

                                    # Заменяем ДОБАВИТЬ на ОБРАБОТАНО
                                    sed -i.bak "${CHECK_LINE}s/ДОБАВИТЬ ТЕКСТ/ОБРАБОТАНО ТЕКСТ/" "$INPUT_FILE"
                                    rm -f "$INPUT_FILE.bak"
                                fi
                            else
                                echo "         ⚠️ Файл изображения не найден: $FULL_IMAGE_PATH"
                            fi
                        fi
                        break
                    fi
                done
            fi

            ((CURRENT_LINE++))
        done
    else
        echo "   ⚠️ Python3 не найден, пропускаем наложение текста"
    fi

    # Копируем новые изображения с текстом в generated/resources
    echo -e "${BLUE}📋 Копируем изображения с текстом в generated/resources${NC}"
    if ls resources/*_withtext.png 2>/dev/null | grep -q .; then
        cp resources/*_withtext.png "$RESOURCES_DIR/" 2>/dev/null
        echo "   ✅ Скопированы изображения с наложенным текстом"
    else
        echo "   ℹ️ Изображения с текстом не найдены"
    fi

echo -e "${BLUE}🔧 Корректируем пути к изображениям и скриптам для HTML${NC}"
    echo -e "${BLUE}   Сервер запускается из generated/, пути resources/ остаются как есть${NC}"

    # Для HTML НЕ меняем пути resources/ - они уже правильные для запуска из generated
    # Сервер запускается из generated/, поэтому resources/ пути корректны
    echo -e "${BLUE}   Пути не требуют коррекции - сервер запускается из generated${NC}"
fi

# Для PDF/PPTX заменяем интерактивные элементы на плейсхолдеры
if [[ "$FORMAT" == "pdf" ]] || [[ "$FORMAT" == "pptx" ]]; then
    echo -e "${BLUE}🖼️  Заменяем интерактивные элементы на плейсхолдеры для $FORMAT${NC}"

    # Удаляем комментарии с промптами для генерации изображений
    echo -e "${BLUE}🧹 Удаляем комментарии с промптами генерации изображений${NC}"
    sed -i '' '/<!-- СОЗДАТЬ ИЗОБРАЖЕНИЕ:/d' "$TEMP_FILE"
    sed -i '' '/<!-- ОБРАБОТАНО ИЗОБРАЖЕНИЕ:/d' "$TEMP_FILE"
    
    # Создаём временный файл для обработки
    TEMP_INTERACTIVE="${TEMP_FILE}.interactive"
    
    # Используем perl для обработки
    if command -v perl &> /dev/null; then
        perl -0777 -pe '
            # Заменяем полные интерактивные блоки включая D3.js скрипты
            # Ищем: <div style="text-align: center"> ... <svg id="*-viz"> ... </div> ... <script src="d3.js"> ... <script>...</script>
            s{
                (<div[^>]*style="[^"]*text-align:\s*center[^"]*"[^>]*>.*?<svg[^>]*id="[^"]*-viz"[^>]*>.*?</div>.*?)
                (<script[^>]*src="[^"]*d3[^"]*"[^>]*></script>.*?)
                (<script>.*?</script>)
            }
            {

**Перейдите в HTML-версию для интерактивной демонстрации**

}gsx;
        ' "$TEMP_FILE" > "$TEMP_INTERACTIVE"
    else
        # Запасной вариант с sed
        # Заменяем блоки с svg на изображения
        sed -E '
            # Для строк с svg и id="-viz"
            /<svg[^>]*id="[^"]+-viz"/ {
                # Заменяем на сообщение
                s/.*/\<div style="text-align: center; padding: 50px; font-size: 18px; color: #666;"\>\<strong\>Перейдите в HTML-версию для интерактивной демонстрации\<\/strong\>\<\/div\>/
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

# Для PPTX упрощаем HTML-таблицы, но сохраняем структуру
if [[ "$FORMAT" == "pptx" ]]; then
    echo -e "${BLUE}📊 Упрощаем HTML-таблицы для PPTX${NC}"
    
    # Создаём временный Python скрипт для упрощения HTML-таблиц
    CONVERT_SCRIPT="${TEMP_FILE}.convert.py"
    cat > "$CONVERT_SCRIPT" << 'EOF'
import re
import sys

def simplify_html_table(html):
    """Упрощает HTML-таблицу, сохраняя базовую структуру для PPTX"""
    
    # Удаляем лишние div-обёртки, но оставляем основную структуру
    # Убираем table-container и table-wrapper, но оставляем table
    html = re.sub(r'<div class="table-container">.*?<div class="table-wrapper">', '', html, flags=re.DOTALL)
    html = re.sub(r'</div>\s*</div>$', '', html)
    
    # Удаляем column-headers div - они мешают Marp
    html = re.sub(r'<div class="column-headers">.*?</div>', '', html, flags=re.DOTALL)
    
    # Упрощаем стили таблицы
    html = re.sub(r'<table[^>]*>', '<table>', html)
    
    return html

def process_file(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Паттерн для поиска HTML-таблиц с классом page_twocolumn
    pattern = r'(<!-- _class: page_twocolumn -->.*?)<div class="table-container">.*?</table>.*?</div>\s*</div>'
    
    def replace_table(match):
        full_match = match.group(0)
        
        # Проверяем, что это таблица с целями
        if '<th>Цель</th>' in full_match and '<th>Смысл</th>' in full_match:
            # Извлекаем заголовки из HTML
            title_match = re.search(r'<h1>([^<]+)</h1>', full_match)
            subtitle_match = re.search(r'<h2>([^<]+)</h2>', full_match)
            
            # Извлекаем саму таблицу
            table_match = re.search(r'<table>.*?</table>', full_match, re.DOTALL)
            
            if table_match:
                result = "<!-- _class: page_twocolumn -->\n\n"
                
                # Добавляем заголовки как обычный Markdown
                if title_match:
                    result += f"# {title_match.group(1)}\n"
                if subtitle_match:
                    result += f"## {subtitle_match.group(1)}\n\n"
                
                # Добавляем упрощённую таблицу
                result += table_match.group(0) + "\n"
                
                return result
        
        # Если это не таблица целей, просто упрощаем HTML
        return simplify_html_table(full_match)
    
    # Обрабатываем все таблицы page_twocolumn
    content = re.sub(pattern, replace_table, content, flags=re.DOTALL)
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        process_file(sys.argv[1])
EOF
    
    # Запускаем Python скрипт для упрощения
    if command -v python3 &> /dev/null; then
        python3 "$CONVERT_SCRIPT" "$TEMP_FILE" || {
            echo -e "${YELLOW}⚠️  Не удалось упростить HTML-таблицы${NC}"
        }
    elif command -v python &> /dev/null; then
        python "$CONVERT_SCRIPT" "$TEMP_FILE" || {
            echo -e "${YELLOW}⚠️  Не удалось упростить HTML-таблицы${NC}"
        }
    else
        echo -e "${YELLOW}⚠️  Python не найден, HTML-таблицы не будут упрощены${NC}"
    fi
    
    # Удаляем временный скрипт
    rm -f "$CONVERT_SCRIPT"
fi

# Запускаем Marp для генерации выходного файла
echo -e "${BLUE}🎨 Генерируем $FORMAT с помощью Marp${NC}"

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

# Определяем параметры для разных форматов - ИСПОЛЬЗУЕМ ЕДИНЫЙ CSS
case "$FORMAT" in
    "html")
        FORMAT_ARGS="--html --bespoke.osc=false"
        ;;
    "pdf")
        FORMAT_ARGS="--pdf --pdf-notes"
        ;;
    "pptx")
        FORMAT_ARGS="--pptx --pptx-editable"
        ;;
esac

echo -e "${BLUE}🎨 Используем тему: $THEME_NAME${NC}"

# Генерируем выходной файл
# Используем единый CSS файл для всех форматов
$MARP_CMD "$TEMP_FILE" \
    $FORMAT_ARGS \
    --theme-set ~/Obsidian/MySecureNotes/.themes \
    --theme "$THEME_NAME" \
    --allow-local-files \
    --no-stdin \
    -o "$TEMP_OUTPUT_FILE" || {
    echo -e "${RED}❌ Ошибка при генерации $FORMAT${NC}"
    exit 1
}

# Перемещаем файл в generated для PDF/PPTX
if [[ "$FORMAT" == "pdf" ]] || [[ "$FORMAT" == "pptx" ]]; then
    echo -e "${BLUE}📦 Перемещаем $FORMAT в каталог generated${NC}"
    mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
fi

# Добавляем миникарту для HTML презентаций
if [[ "$FORMAT" == "html" ]]; then
    echo -e "${BLUE}🗺️  Добавляем миникарту навигации${NC}"

    # Создаем миникарту на основе секций в исходном файле
    create_minimap "$INPUT_FILE" "$OUTPUT_FILE" "$GENERATED_DIR"
fi

# Удаляем временные файлы
echo -e "${BLUE}🧹 Очистка временных файлов${NC}"
rm -f "$TEMP_FILE" "$MERMAID_CONFIG"
rm -f temp_plot_*.plt temp_plot_*_full.plt

echo -e "${GREEN}✅ Готово!${NC}"
echo "   Файл презентации: $OUTPUT_FILE"
if [[ "$FORMAT" == "pptx" ]]; then
    echo "   PNG диаграммы и графики: $RESOURCES_DIR/"
else
    echo "   SVG диаграммы и PNG графики: $RESOURCES_DIR/"
fi

# Для HTML формата - запускаем локальный HTTP-сервер и открываем в браузере
if [[ "$FORMAT" == "html" ]] && [[ -z "$SKIP_OPEN" ]]; then
    # Определяем порт для HTTP-сервера
    HTTP_PORT=8888

    # Открываем HTML файл в Comet браузере, переиспользуя вкладку
    PRESENTATION_NAME=$(basename "$OUTPUT_FILE" .html)
    echo -e "${BLUE}🚀 Открываем презентацию: $OUTPUT_FILE${NC}"

    # Используем AppleScript для переиспользования вкладки с тем же именем
    osascript -e "
    tell application \"Comet\"
        activate
        set targetURL to \"file://$OUTPUT_FILE\"
        set tabFound to false

        repeat with w in windows
            repeat with t in tabs of w
                if name of t contains \"$PRESENTATION_NAME\" then
                    set URL of t to targetURL
                    set active tab index of w to index of t
                    set tabFound to true
                    exit repeat
                end if
            end repeat
            if tabFound then exit repeat
        end repeat

        if not tabFound then
            open location targetURL
        end if
    end tell
    " 2>/dev/null || open -a "Comet" "$OUTPUT_FILE"
fi
