const { Marp } = require('@marp-team/marp-core')

module.exports = (opts) => {
  // Создаём экземпляр Marp с поддержкой HTML
  const marp = new Marp({
    ...opts,
    html: true
  })
  
  // Сохраняем оригинальный обработчик fence
  const originalFence = marp.markdown.renderer.rules.fence
  
  // Переопределяем обработчик для блоков кода
  marp.markdown.renderer.rules.fence = function(tokens, idx, options, env, renderer) {
    const token = tokens[idx]
    const info = token.info ? token.info.trim() : ''
    
    if (info === 'mermaid') {
      // Для mermaid блоков возвращаем div с классом mermaid
      // Важно: НЕ используем pre, так как Mermaid ожидает div
      return `<div class="mermaid">${token.content}</div>\n`
    }
    
    // Для остальных блоков используем оригинальный обработчик
    return originalFence.call(this, tokens, idx, options, env, renderer)
  }
  
  // Добавляем обработку для вставки Mermaid скриптов
  marp.use((md) => {
    // Отслеживаем наличие mermaid блоков
    const originalParse = md.parse.bind(md)
    md.parse = function(src, env) {
      const tokens = originalParse(src, env)
      
      // Проверяем наличие mermaid блоков
      let hasMermaid = false
      for (const token of tokens) {
        if (token.type === 'fence' && token.info && token.info.trim() === 'mermaid') {
          hasMermaid = true
          break
        }
      }
      
      // Помечаем в окружении
      if (hasMermaid && env) {
        env.hasMermaid = true
      }
      
      return tokens
    }
  })
  
  // Переопределяем метод render для добавления Mermaid поддержки
  const originalRender = marp.render.bind(marp)
  
  marp.render = function(markdown, env = {}) {
    // Вызываем оригинальный рендер
    const result = originalRender(markdown, env)
    
    // Если есть mermaid блоки, модифицируем HTML
    if (env.hasMermaid || result.html.includes('class="mermaid"')) {
      // Находим позицию </body> для вставки скриптов в конец
      const bodyEndPos = result.html.lastIndexOf('</body>')
      
      const mermaidScript = `
<!-- Mermaid.js support -->
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
console.log('Mermaid script loaded');

// Конфигурация Mermaid
const config = {
  startOnLoad: true,
  theme: 'base',
  themeVariables: {
    primaryColor: '#ffffff',
    primaryTextColor: '#333333',
    primaryBorderColor: '#5B10B3',
    lineColor: '#5B10B3',
    secondaryColor: '#EEE',
    tertiaryColor: '#f0f0f0',
    background: '#ffffff',
    mainBkg: '#ffffff',
    secondBkg: '#EEE',
    tertiaryBkg: '#f0f0f0',
    darkMode: false,
    fontFamily: 'Roboto, sans-serif',
    fontSize: '20px'  /* Увеличено до 22px */
  },
  flowchart: {
    useMaxWidth: false,  // Изменено на false для контроля размера
    htmlLabels: true,
    curve: 'linear',
    rankSpacing: 30,     // Расстояние между уровнями
    nodeSpacing: 15,     // Расстояние между узлами
    padding: 5
  }
};

// Инициализация Mermaid
mermaid.initialize(config);

// Функция для рендеринга диаграмм
function renderMermaid() {
  console.log('Looking for mermaid elements...');
  const elements = document.querySelectorAll('.mermaid');
  console.log('Found', elements.length, 'mermaid elements');
  
  elements.forEach((element, index) => {
    if (!element.getAttribute('data-processed')) {
      console.log('Processing mermaid element', index);
      
      // Определяем направление диаграммы из текста
      const text = element.textContent;
      if (text.includes('graph LR') || text.includes('graph RL')) {
        element.setAttribute('data-direction', 'LR');
      } else if (text.includes('graph TD') || text.includes('graph TB')) {
        element.setAttribute('data-direction', 'TD');
      }
      
      element.setAttribute('data-processed', 'true');
      
      // Mermaid автоматически обработает элементы с классом mermaid
      try {
        mermaid.init(undefined, element);
      } catch (e) {
        console.error('Mermaid init error:', e);
      }
    }
  });
}

// Запускаем рендеринг несколько раз для надёжности
document.addEventListener('DOMContentLoaded', function() {
  console.log('DOM loaded, rendering mermaid...');
  setTimeout(renderMermaid, 100);
  setTimeout(renderMermaid, 500);
});

window.addEventListener('load', function() {
  console.log('Window loaded, rendering mermaid...');
  setTimeout(renderMermaid, 100);
});

// Для отладки - проверяем, что Mermaid загружен
setTimeout(function() {
  if (typeof mermaid !== 'undefined') {
    console.log('Mermaid is loaded:', mermaid);
    renderMermaid();
  } else {
    console.error('Mermaid is not loaded!');
  }
}, 1000);
</script>
<style>
/* Стили для Mermaid диаграмм */
.mermaid {
  display: block;
  text-align: center;
  margin: 10px auto;  /* Уменьшаем отступы */
  background: transparent;
  font-family: 'Roboto', sans-serif !important;
  /* Увеличиваем высоту диаграммы */
  max-height: 360px;  /* Уменьшено с 420px */
  overflow: visible;
}

.mermaid svg {
  max-width: 100%;
  max-height: 360px;  /* Уменьшено */
  width: auto !important;
  height: auto !important;
  transform: scale(1.0);  /* Уменьшено с 1.3 */
  transform-origin: center center;
}

/* Для горизонтальных диаграмм (LR) делаем текст крупнее */
.mermaid[data-direction="LR"] svg,
.mermaid[data-direction="RL"] svg {
  min-width: 700px;  /* Увеличено */
  transform: scale(1.2);  /* Немного уменьшено */
  transform-origin: center;
}

/* Для вертикальных диаграмм (TD/TB) */
.mermaid[data-direction="TD"] svg,
.mermaid[data-direction="TB"] svg {
  transform: scale(1.0);  /* Значительно уменьшено с 1.5 */
  transform-origin: center center;  /* Центрируем */
  max-height: 360px;  /* Ограничиваем высоту */
}

/* Убедимся, что диаграммы видны на всех слайдах */
section .mermaid {
  display: block !important;
  visibility: visible !important;
}

/* Специфичные стили для разных типов слайдов */
section.page .mermaid,
section.page_section .mermaid,
section.page_twocolumn .mermaid,
section.page_image .mermaid {
  margin: 10px auto;  /* Уменьшаем отступы */
}

/* Стили для узлов - увеличиваем размер */
.node rect {
  fill: #EEE !important;
  stroke: #5B10B3 !important;
  stroke-width: 2px !important;
}

.node text {
  font-family: 'Roboto', sans-serif !important;
  fill: #333333 !important;
  font-size: 20px !important;  /* Уменьшено с 22px */
}

/* Стили для стрелок */
.edgePath path {
  stroke: #5B10B3 !important;
  stroke-width: 2px !important;
}

.edgeLabel {
  background-color: white !important;
  font-family: 'Roboto', sans-serif !important;
  font-size: 18px !important;  /* Уменьшено с 20px */
}

/* Метки на стрелках */
.edgeLabel rect {
  fill: red !important;
  stroke: none !important;
}

/* Увеличиваем размер текста в диаграммах */
.mermaid text {
  font-size: 18px !important;  /* Уменьшено с 22px */
}

/* Для ещё большего увеличения можно добавить масштабирование всей диаграммы */
.mermaid svg {
  max-width: 100%;
  max-height: 420px;
  width: auto !important;
  height: auto !important;
  transform: scale(1.3);  /* Увеличено масштабирование */
  transform-origin: center center;
}

/* Для маленьких экранов или при показе презентации */
@media (max-width: 1024px) {
  .mermaid svg {
    max-height: 250px;  /* Увеличено с 250px (+10%) */
  }
}
</style>
`
      
      // Вставляем скрипты перед </body>
      if (bodyEndPos !== -1) {
        result.html = result.html.slice(0, bodyEndPos) + mermaidScript + result.html.slice(bodyEndPos)
      } else {
        // Fallback - добавляем в конец
        result.html += mermaidScript
      }
    }
    
    return result
  }
  
  return marp
}
