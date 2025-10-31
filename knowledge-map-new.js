(function () {
  console.log('[DEBUG] Knowledge Map скрипт загружается...', new Date());
  if (window.__knowledgeMapInitialized) return;

  const CONFIG = {
    storageKey: 'knowledge-map.v4',
    hexLayout: (() => {
      const centers = [];
      const screenW = 1152;  // Обновлено под новые размеры
      const screenH = 580;

      // Оптимальный размер для идеального сотового паттерна
      const size = 18;  // Размер шестиугольника (уменьшен с 35)

      // Фиксированная сетка (не зависит от размера)
      const cols = 35;
      const rows = 20;

      // Правильные расстояния для offset coordinates
      const startX = 20;   // Отступ слева
      const startY = 15;   // Отступ сверху

      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          // Формула для offset coordinates (прямоугольная сетка)
          const x = startX + size * Math.sqrt(3) * (col + 0.5 * (row % 2));
          const y = startY + size * 3/2 * row;

          // Проверяем границы
          if (x >= -size && x <= screenW + size &&
              y >= -size && y <= screenH + size) {
            centers.push({ x, y, size });
          }
        }
      }

      return centers;
    })(),
    imageUrl: 'resources/image_kubernetes.png',
    tagToCells: null, // Будет инициализировано один раз

    // Маппинг тегов из слайдов к концептам MindMap
    tagToMindMapConcepts: {
      'architecture': ['Authentication', 'Authorization', 'Admission Control'],
      'authentication': ['Authentication', 'OIDC', 'ServiceAccounts'],
      'auth': ['Authentication', 'OIDC'],
      'authorization': ['Authorization', 'RBAC'],
      'authz': ['Authorization', 'RBAC'],
      'rbac': ['RBAC', 'Roles', 'ClusterRoles', 'Bindings'],
      'admission': ['Admission Control', 'OPA', 'Validation'],
      'policy': ['Admission Control', 'Pod Security'],
      'opa': ['OPA', 'Gatekeeper'],
      'gatekeeper': ['Gatekeeper'],
      'pod-security': ['Pod Security'],
      'runtime': ['Runtime Security', 'Falco', 'Tetragon'],
      'monitoring': ['Runtime Security', 'Monitoring'],
      'networkpolicy': ['Network Security', 'NetworkPolicy'],
      'network-security': ['Network Security', 'Zero Trust'],
      'zero-trust': ['Zero Trust'],
      'secrets': ['Data Protection', 'Secrets', 'etcd Encryption', 'External Secrets'],
      'encryption': ['Data Protection', 'Encryption'],
      'kms': ['Data Protection', 'KMS'],
      'image-signing': ['Data Protection']
    },

    tagLabels: {
      'architecture': 'Архитектура безопасности',
      'authentication': 'Аутентификация',
      'authorization': 'Авторизация',
      'rbac': 'RBAC / роли',
      'admission': 'Admission Control',
      'opa': 'OPA',
      'gatekeeper': 'Gatekeeper',
      'pod-security': 'Pod Security (PSA)',
      'policy': 'Политики безопасности',
      'runtime': 'Runtime Security',
      'container-escape': 'Container Escape',
      'privileged': 'Privileged контейнеры',
      'networkpolicy': 'NetworkPolicy',
      'zero-trust': 'Zero Trust сети',
      'secrets': 'Secrets управление',
      'kms': 'KMS / Vault',
      'encryption': 'Шифрование / TLS',
      'etcd': 'etcd безопасность',
      'image-signing': 'Подпись образов',
      'sbom': 'SBOM / зависимости',
      'supply-chain': 'Supply Chain',
      'audit': 'Audit / Логи',
      'monitoring': 'Мониторинг / Compliance',
    },
    tagShortLabels: {}, // Будет заполняться динамически из CSS классов с суффиксом $
    defaultRelations: [
      ['rbac', 'networkpolicy'],
      ['rbac', 'pod-security'],
      ['rbac', 'opa'],
      ['opa', 'image-signing'],
      ['opa', 'secrets'],
      ['opa', 'audit'],
      ['image-signing', 'supply-chain'],
    ],
    tabOrder: ['hex', 'mind'],
  };

  const CSS = `/* knowledge map overlay */
  .know-overlay{position:fixed;inset:auto 12px 12px auto;z-index:9999;display:none;gap:8px;align-items:center}
  .know-overlay.show{display:flex}
  .know-return-overlay{position:fixed;top:12px;left:12px;z-index:9998;display:none;animation:km-fade-in .3s ease forwards}
  .know-return-overlay.show{display:block}
  .know-return-btn{cursor:pointer;border-radius:8px;padding:8px 12px;background:rgba(2,6,23,.85);color:#fff;border:1px solid rgba(255,255,255,.15);font:600 12px/1 ui-sans-serif;backdrop-filter:blur(8px);transition:all .2s ease;box-shadow:0 4px 12px rgba(0,0,0,.25)}
  .know-return-btn:hover{background:rgba(2,6,23,.95);border-color:rgba(255,255,255,.25);transform:translateY(-1px);box-shadow:0 6px 16px rgba(0,0,0,.35)}
  .know-btn{cursor:pointer;border-radius:999px;padding:8px 12px;background:rgba(2,6,23,.72);color:#fff;border:1px solid rgba(255,255,255,.12);font:600 12px/1 ui-sans-serif}
  .know-meter{height:6px;background:rgba(255,255,255,.12);border-radius:999px;overflow:hidden;min-width:120px}
  .know-meter>i{display:block;height:100%;width:0;background:linear-gradient(90deg,#10b981,#a855f7);transition:width .25s ease}
  .know-panel{position:fixed;inset:0;width:100vw;height:100vh;background:rgba(15,23,42,.95);backdrop-filter:blur(8px);color:#fff;border:none;border-radius:0;box-shadow:none;display:none;flex-direction:column;z-index:10000}
  .know-panel.show{display:flex}
  .know-head{display:flex;gap:8px;align-items:center;justify-content:space-between;padding:10px 12px;border-bottom:1px solid rgba(255,255,255,.08)}
  .know-tabs{display:flex;gap:6px}
  .know-tab{padding:6px 10px;border-radius:999px;border:1px solid rgba(255,255,255,.12);cursor:pointer;background:transparent;color:#fff;font:600 12px/1 ui-sans-serif;opacity:.7;transition:opacity .2s}
  .know-tab.active{opacity:1;background:rgba(255,255,255,.08)}
  .know-body{position:relative;flex:1;display:flex;align-items:center;justify-content:center;overflow:hidden}
  .know-legend{display:flex;gap:8px;flex-wrap:wrap;align-items:center;max-width:48%}
  .know-chip{padding:4px 8px;border-radius:999px;border:1px solid rgba(255,255,255,.15);font:500 11px/1 ui-sans-serif;opacity:.6;text-transform:none}
  .know-chip.done{opacity:1;border-color:#22c55e}
  .know-close{opacity:.6;cursor:pointer}
  svg.know-svg{width:100%;height:100%}
  .hex-bg{opacity:1}
  .reveal-mask-bg{fill:#000;opacity:0.8}
  .reveal-mask-path{fill:#fff;opacity:1}
  .hex-outline{fill:rgba(0,0,0,0.4);stroke:rgba(255,255,255,.2);stroke-width:1;opacity:.8}
  .hex-outline.revealed{opacity:1;fill:none;stroke:none}
  .hex-label{fill:#fff;font:600 11px/1 ui-sans-serif;text-anchor:middle;dominant-baseline:middle;opacity:0;pointer-events:none}
  .hex-label.show{opacity:.95}
  .hex-label.revealed{fill:#fff;font-size:12px;font-weight:700;stroke:#000;stroke-width:1px;paint-order:stroke fill}
  .mm-node{fill:#0b1220;stroke:rgba(255,255,255,.25);stroke-width:1;transition:fill .25s,opacity .2s}
  .mm-node.revealed{fill:#1e293b;stroke:#22c55e;stroke-width:2}
  .mm-center{fill:#1e293b;stroke:rgba(255,255,255,.4);stroke-width:2}
  .mm-main-node{fill:#0f172a;stroke:rgba(255,255,255,.3);stroke-width:2}
  .mm-main-node.revealed{fill:#1e293b;stroke:#22c55e;stroke-width:3}
  .mm-child-node{fill:#0a0e1a;stroke:rgba(255,255,255,.2);stroke-width:1}
  .mm-child-node.revealed{fill:#134e4a;stroke:#10b981;stroke-width:2}
  .mm-grandchild-node{fill:#050810;stroke:rgba(255,255,255,.15);stroke-width:1}
  .mm-grandchild-node.revealed{fill:#0c4a6e;stroke:#0ea5e9;stroke-width:2}
  .mm-label{fill:#fff;font:600 10px/1 ui-sans-serif;text-anchor:middle;dominant-baseline:middle;opacity:.85}
  .mm-center-label{font:bold 14px/1 ui-sans-serif;opacity:1}
  .mm-main-label{font:bold 11px/1 ui-sans-serif;opacity:.9}
  .mm-child-label{font:600 9px/1 ui-sans-serif;opacity:.8}
  .mm-grandchild-label{font:600 8px/1 ui-sans-serif;opacity:.75}
  .mm-branch{stroke:rgba(255,255,255,.15);stroke-width:1;transition:stroke .2s,stroke-width .2s}
  .mm-level-1-branch{stroke:rgba(255,255,255,.2);stroke-width:2}
  .mm-level-2-branch{stroke:rgba(255,255,255,.15);stroke-width:1.5}
  .mm-level-3-branch{stroke:rgba(255,255,255,.1);stroke-width:1}
  .mm-branch.revealed,.mm-level-1-branch.revealed{stroke:#22c55e;stroke-width:3}
  .mm-level-2-branch.revealed{stroke:#10b981;stroke-width:2}
  .mm-level-3-branch.revealed{stroke:#0ea5e9;stroke-width:1.5}
  @media (max-width:900px){.know-panel{height:60vh}.know-legend{max-width:58%}}
  .progress-fullscreen{position:fixed;inset:0;z-index:10050;display:flex;align-items:center;justify-content:center;background:radial-gradient(circle at center,#0f172a 0%,#020617 100%);animation:km-fade .35s ease forwards}
  .progress-map-wrap{width:min(92vw,1100px);height:min(86vh,700px);background:rgba(15,23,42,.92);border:1px solid rgba(255,255,255,.12);border-radius:20px;box-shadow:0 25px 90px rgba(0,0,0,.45);padding:20px 24px;display:flex;flex-direction:column;gap:16px;animation:km-zoom .4s ease forwards}
  .progress-tabs{display:flex;gap:12px}
  .progress-tab{padding:8px 16px;border-radius:999px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.04);color:#fff;font:600 13px/1 ui-sans-serif;cursor:pointer;opacity:.65;transition:opacity .2s,background .2s,border .2s}
  .progress-tab.active{opacity:1;background:rgba(255,255,255,.12);border-color:rgba(255,255,255,.35)}
  .progress-stage{position:relative;flex:1;overflow:hidden}
  .progress-stage [data-km-view]{position:absolute;inset:0;width:100%;height:100%;display:none}
  .progress-stage [data-km-active="true"]{display:block}
  .progress-legend{display:flex;justify-content:center}
  .progress-legend-inner{display:flex;gap:8px;flex-wrap:wrap;justify-content:center}
  .progress-legend-inner .know-chip{opacity:.8}
  body.progress-fullscreen-open .know-overlay{opacity:0;pointer-events:none;transition:opacity .2s ease}
  body.progress-fullscreen-open .know-panel{display:none!important}
  @keyframes km-fade{from{opacity:0}to{opacity:1}}
  @keyframes km-zoom{from{transform:scale(.94);opacity:0}to{transform:scale(1);opacity:1}}
  @keyframes km-fade-in{from{opacity:0;transform:translateY(-5px)}to{opacity:1;transform:translateY(0)}}
  `;

  function waitForDomReady(cb) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', cb, { once: true });
    } else {
      cb();
    }
  }

  function injectStyle() {
    if (document.getElementById('km-style')) return;
    const style = document.createElement('style');
    style.id = 'km-style';
    style.textContent = CSS;
    document.head.appendChild(style);
  }

  function createOverlayDom() {
    const overlay = document.createElement('div');
    overlay.className = 'know-overlay';
    overlay.innerHTML = `
      <button type="button" class="know-btn" id="kmToggle">🗺️ Карта знаний</button>
      <div class="know-meter" title="Прогресс знаний"><i id="kmProgressBar"></i></div>
      <span id="kmProgressPct" style="color:#fff;font:600 12px/1 ui-sans-serif;opacity:.85">0%</span>
    `;

    const panel = document.createElement('div');
    panel.className = 'know-panel';
    panel.id = 'kmPanel';
    panel.innerHTML = `
      <div class="know-head">
        <div class="know-tabs">
          <button type="button" class="know-tab active" data-km-tab="hex">Hex-карта</button>
          <button type="button" class="know-tab" data-km-tab="mind">Mindmap</button>
        </div>
        <div class="know-legend" id="kmLegend"></div>
        <div class="know-close" id="kmClose" title="Скрыть карту">✕</div>
      </div>
      <div class="know-body">
        <svg class="know-svg" id="kmHexSvg" viewBox="0 -10 1152 590" preserveAspectRatio="xMidYMid meet" style="width:90vw;height:80vh"></svg>
        <svg class="know-svg" id="kmMindSvg" viewBox="0 0 1000 650" preserveAspectRatio="xMidYMid meet" style="display:none"></svg>
      </div>
    `;

    // Создаем кнопку возврата к карте
    const returnOverlay = document.createElement('div');
    returnOverlay.className = 'know-return-overlay';
    returnOverlay.id = 'kmReturnOverlay';
    returnOverlay.innerHTML = `
      <button type="button" class="know-return-btn" id="kmReturnBtn">
        🗺️ Вернуться к карте знаний
      </button>
    `;

    document.body.appendChild(overlay);
    document.body.appendChild(panel);
    document.body.appendChild(returnOverlay);

    return {
      overlay,
      panel,
      returnOverlay,
      toggleBtn: overlay.querySelector('#kmToggle'),
      meterFill: overlay.querySelector('#kmProgressBar'),
      meterPct: overlay.querySelector('#kmProgressPct'),
      closeBtn: panel.querySelector('#kmClose'),
      returnBtn: returnOverlay.querySelector('#kmReturnBtn'),
      legend: panel.querySelector('#kmLegend'),
      tabButtons: Array.from(panel.querySelectorAll('[data-km-tab]')),
      hexSvg: panel.querySelector('#kmHexSvg'),
      mindSvg: panel.querySelector('#kmMindSvg'),
    };
  }

  function createHexMap(dom) {
    const svg = dom.hexSvg;
    const { hexLayout, imageUrl } = CONFIG;
    const outlines = [];
    const labels = [];

    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
    const mask = document.createElementNS('http://www.w3.org/2000/svg', 'mask');
    mask.setAttribute('id', 'kmRevealMask');

    const maskBg = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
    maskBg.setAttribute('class', 'reveal-mask-bg');
    maskBg.setAttribute('x', '0');
    maskBg.setAttribute('y', '0');
    maskBg.setAttribute('width', '1152');
    maskBg.setAttribute('height', '580');
    mask.appendChild(maskBg);
    defs.appendChild(mask);
    svg.appendChild(defs);

    const img = document.createElementNS('http://www.w3.org/2000/svg', 'image');
    img.setAttributeNS('http://www.w3.org/1999/xlink', 'href', imageUrl);
    img.setAttribute('x', '0');
    img.setAttribute('y', '0');
    img.setAttribute('width', '1152');
    img.setAttribute('height', '580');
    img.setAttribute('preserveAspectRatio', 'xMidYMid slice');
    img.setAttribute('class', 'hex-bg');
    img.setAttribute('mask', 'url(#kmRevealMask)');
    svg.appendChild(img);

    hexLayout.forEach((cell, idx) => {
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', buildHexPath(cell));
      path.setAttribute('class', 'hex-outline');
      path.dataset.kmIndex = String(idx);
      svg.appendChild(path);
      outlines.push(path);

      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      label.setAttribute('x', cell.x);
      label.setAttribute('y', cell.y);
      label.setAttribute('class', 'hex-label');
      label.textContent = '';
      svg.appendChild(label);
      labels.push(label);
    });

    return { mask, outlines, labels };
  }

  function buildHexPath({ x, y, size }) {
    const pts = [];
    for (let k = 0; k < 6; k += 1) {
      const angle = Math.PI / 6 + k * Math.PI / 3;
      pts.push([
        x + size * Math.cos(angle),
        y + size * Math.sin(angle),
      ]);
    }
    return `M${pts.map((p) => `${p[0].toFixed(1)},${p[1].toFixed(1)}`).join('L')}Z`;
  }

  function createMindNodes(dom) {
    const svg = dom.mindSvg;
    const nodeByTag = new Map();
    const cx = 500;
    const cy = 325;

    // Ищем краткое название в классах первой страницы
    let presentationTitle = null;

    // Ищем первый слайд
    const firstSlide = document.querySelector('svg.bespoke-marp-slide');
    if (firstSlide) {
      const firstSection = firstSlide.querySelector('foreignObject > section');
      if (firstSection) {
        // Ищем concept_ класс на первой странице
        const conceptClass = Array.from(firstSection.classList).find(cls => cls.startsWith('concept_'));
        if (conceptClass) {
          let conceptName = conceptClass.replace(/^concept_/, '');
          // Убираем суффикс $ABBREVIATION перед обработкой
          const dollarMatch = conceptName.match(/^(.+)\$([A-Z]{2,8})$/);
          if (dollarMatch) {
            conceptName = dollarMatch[1]; // Убираем $ABBREVIATION
          }
          conceptName = conceptName.replace(/_/g, ' ');
          presentationTitle = conceptName.charAt(0).toUpperCase() + conceptName.slice(1);
        }
      }
    }

    // Если не нашли в классах, ищем в метаданных или фолбэки
    if (!presentationTitle) {
      const shortTitle = CONFIG.imageUrl ?
        (document.head.innerHTML.match(/<!-- _knowledge_map_title: '([^']+)' -->/) || [])[1] : null;
      presentationTitle = shortTitle ||
                         document.title ||
                         document.querySelector('h1')?.textContent ||
                         'Presentation';
    }

    // Динамически извлекаем структуру из концептов в слайдах
    const mindMapStructure = {};
    mindMapStructure[presentationTitle] = { children: [] };

    // Ищем все слайды с концептами
    const slides = Array.from(document.querySelectorAll('svg.bespoke-marp-slide'));
    const allConcepts = new Set();

    slides.forEach(slide => {
      const section = slide.querySelector('foreignObject > section');
      if (!section) return;

      section.className.split(/\s+/).forEach(cls => {
        if (cls.startsWith('concept_')) {
          let conceptPath = cls.replace(/^concept_/, '');
          // Убираем $ABBREVIATION суффиксы ПЕРЕД разделением на части
          conceptPath = conceptPath.replace(/\$[A-Z]{2,8}$/, '');
          const parts = conceptPath.split('-');

          // Пропускаем если это только корневой концепт
          if (parts.length === 1 && parts[0].toLowerCase() === presentationTitle.toLowerCase()) {
            return;
          }

          // Строим иерархию из частей
          let currentParent = presentationTitle;
          let currentPath = "";

          parts.forEach((part, index) => {
            // Пропускаем все сокращения (заглавные буквы 2-5 символов)
            const isAbbreviation = /^[A-Z]{2,8}$/.test(part);

            if (isAbbreviation) {
              console.log(`[MINDMAP] Пропускаем сокращение: ${part}`);
              return; // Пропускаем сокращения
            }

            // Строим полный путь - убираем суффиксы $ABBREVIATION из ключей
            let keyPart = part;
            const keyDollarMatch = part.match(/^(.+)\$([A-Z]{2,8})$/);
            if (keyDollarMatch) {
              console.log(`[MINDMAP KEY] Убираем суффикс: "${part}" -> "${keyDollarMatch[1]}"`);
              keyPart = keyDollarMatch[1]; // Убираем $ABBREVIATION из ключа
            }
            currentPath = currentPath ? `${currentPath}-${keyPart}` : keyPart;
            console.log(`[MINDMAP KEY] Построили путь: "${currentPath}" из part: "${part}" и keyPart: "${keyPart}"`);

            // Для отображения убираем суффиксы $ABBREVIATION и обрабатываем составные концепты
            let displayPart = part;
            const dollarMatch = part.match(/^(.+)\$([A-Z]{2,8})$/);
            if (dollarMatch) {
              displayPart = dollarMatch[1]; // Убираем $ABBREVIATION для отображения
            }

            const conceptName = displayPart.replace(/_/g, ' ');
            const capitalizedName = conceptName.split(' ').map(word =>
              word.charAt(0).toUpperCase() + word.slice(1)
            ).join(' ');

            allConcepts.add(currentPath);

            // Инициализируем структуру если её нет
            if (!mindMapStructure[currentPath]) {
              // Дополнительно убираем суффиксы из displayName на всякий случай
              let cleanDisplayName = capitalizedName;
              const dollarMatch = capitalizedName.match(/^(.+)\$([A-Z]{2,8})$/);
              if (dollarMatch) {
                cleanDisplayName = dollarMatch[1]; // Убираем $ABBREVIATION
              }
              console.log(`[MINDMAP STRUCTURE] Создаем структуру для ключа: "${currentPath}" с displayName: "${cleanDisplayName}"`);
              mindMapStructure[currentPath] = { children: [], displayName: cleanDisplayName };
            }

            // Добавляем в дочерние элементы родителя
            if (!mindMapStructure[currentParent].children.includes(currentPath)) {
              mindMapStructure[currentParent].children.push(currentPath);
            }

            currentParent = currentPath;
          });
        }
      });
    });

    console.log('Динамически извлеченная структура mindmap:', mindMapStructure);

    // Создаем центральный узел
    const centerGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    const centerCircle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    centerCircle.setAttribute('cx', cx);
    centerCircle.setAttribute('cy', cy);
    centerCircle.setAttribute('r', 45);
    centerCircle.setAttribute('class', 'mm-node mm-center');

    const centerLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    centerLabel.setAttribute('x', cx);
    centerLabel.setAttribute('y', cy);
    centerLabel.setAttribute('class', 'mm-label mm-center-label');
    centerLabel.textContent = presentationTitle;

    centerGroup.appendChild(centerCircle);
    centerGroup.appendChild(centerLabel);
    svg.appendChild(centerGroup);

    // Функция для вычисления абсолютной позиции узла
    function getAbsolutePosition(conceptName, parentPos = { x: cx, y: cy }) {
      const config = mindMapStructure[conceptName];
      if (!config) return parentPos;

      const { angle, radius } = config.position;
      return {
        x: parentPos.x + radius * Math.cos(angle),
        y: parentPos.y + radius * Math.sin(angle)
      };
    }

    // Функция для автоматического расчета позиций узлов
    function calculateNodePositions(structure, rootName, rootPos, rootAngle = 0) {
      const positions = new Map();
      const angles = new Map();
      const levels = new Map();

      // Начинаем с корня
      positions.set(rootName, rootPos);
      angles.set(rootName, rootAngle);
      levels.set(rootName, 0);

      // Рекурсивно обрабатываем детей
      function processChildren(parentName, parentLevel, visited = new Set()) {
        // Защита от циклов
        if (visited.has(parentName) || parentLevel > 4) return;
        visited.add(parentName);

        const parentConfig = structure[parentName];
        if (!parentConfig || !parentConfig.children || parentConfig.children.length === 0) return;

        const parentPos = positions.get(parentName);
        const parentAngle = angles.get(parentName);
        const children = parentConfig.children;

        // Определяем радиус для детей в зависимости от уровня
        // Центральный уровень: радиус уменьшен на 30% (180 * 0.7 = 126)
        const radius = parentLevel === 0 ? 126 : (parentLevel === 1 ? 90 : 70);

        // Рассчитываем углы для детей
        const childCount = children.length;
        let childAngle, angleStep;

        if (parentLevel === 0) {
          // Для центрального уровня: распределяем на 360 градусов
          angleStep = (2 * Math.PI) / childCount;
          childAngle = index => index * angleStep;
        } else {
          // Для остальных уровней: ±60° разброс как было
          const angleSpread = childCount === 1 ? 0 : Math.PI / 3;
          const startAngle = parentAngle - angleSpread / 2;
          angleStep = childCount > 1 ? angleSpread / (childCount - 1) : 0;
          childAngle = index => childCount === 1 ? parentAngle : startAngle + index * angleStep;
        }

        children.forEach((childName, index) => {
          const currentChildAngle = childAngle(index);

          const childPos = {
            x: parentPos.x + radius * Math.cos(currentChildAngle),
            y: parentPos.y + radius * Math.sin(currentChildAngle)
          };

          positions.set(childName, childPos);
          angles.set(childName, currentChildAngle);
          levels.set(childName, parentLevel + 1);

          // Рекурсивно обрабатываем детей этого узла
          processChildren(childName, parentLevel + 1, new Set(visited));
        });
      }

      processChildren(rootName, 0);
      return { positions, angles, levels };
    }

    // Рассчитываем все позиции автоматически
    const { positions, angles, levels } = calculateNodePositions(
      mindMapStructure,
      presentationTitle,
      { x: cx, y: cy }
    );

    // Первый проход: создаем все связи (линии)
    Array.from(positions.entries()).forEach(([conceptName, pos]) => {
      if (conceptName === presentationTitle) return; // Пропускаем центральный узел

      // Находим родителя
      let parentName = null;
      for (const [name, config] of Object.entries(mindMapStructure)) {
        if (config.children && config.children.includes(conceptName)) {
          parentName = name;
          break;
        }
      }

      if (parentName && positions.has(parentName)) {
        const parentPos = positions.get(parentName);
        const level = levels.get(conceptName);

        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', parentPos.x);
        line.setAttribute('y1', parentPos.y);
        line.setAttribute('x2', pos.x);
        line.setAttribute('y2', pos.y);
        line.setAttribute('class', `mm-branch mm-level-${level}-branch`);
        line.dataset.kmTag = conceptName; // Используем концепт-ключ как есть
        svg.appendChild(line);
      }
    });

    // Второй проход: создаем все узлы (чтобы они были поверх линий)
    Array.from(positions.entries()).forEach(([conceptName, pos]) => {
      if (conceptName === presentationTitle) return; // Пропускаем центральный узел - он уже создан

      const level = levels.get(conceptName);
      const nodeRadius = level === 1 ? 30 : (level === 2 ? 22 : 16);
      const cssClass = level === 1 ? 'mm-main-node' : (level === 2 ? 'mm-child-node' : 'mm-grandchild-node');
      const labelClass = level === 1 ? 'mm-main-label' : (level === 2 ? 'mm-child-label' : 'mm-grandchild-label');

      // Создаем группу для узла
      const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');

      // Узел
      const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      circle.setAttribute('cx', pos.x);
      circle.setAttribute('cy', pos.y);
      circle.setAttribute('r', nodeRadius);
      circle.setAttribute('class', `mm-node ${cssClass}`);
      circle.dataset.kmTag = conceptName; // Используем концепт-ключ как есть

      // Подпись
      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      label.setAttribute('x', pos.x);
      label.setAttribute('y', pos.y);
      label.setAttribute('class', `mm-label ${labelClass}`);
      label.dataset.kmTag = conceptName; // Используем концепт-ключ как есть

      // Для отображения используем displayName или красиво форматируем ключ
      console.log(`[MINDMAP DISPLAY] Ищем displayName для ключа: "${conceptName}"`);
      let displayName = mindMapStructure[conceptName]?.displayName;
      console.log(`[MINDMAP DISPLAY] Найден displayName: "${displayName}" для ключа: "${conceptName}"`);
      if (!displayName) {
        console.log(`[MINDMAP DISPLAY] DisplayName не найден, используем fallback для: "${conceptName}"`);
        // Fallback: берем только последнюю часть после последнего дефиса
        let lastPart = conceptName;
        const dollarMatch = conceptName.match(/^(.+)\$([A-Z]{2,8})$/);
        if (dollarMatch) {
          console.log(`[MINDMAP DISPLAY] Убираем $ABBREVIATION: "${conceptName}" -> "${dollarMatch[1]}"`);
          lastPart = dollarMatch[1]; // Убираем $ABBREVIATION
        }

        // Берем только часть после последнего дефиса (для иерархии)
        const parts = lastPart.split('-');
        const finalPart = parts[parts.length - 1];

        // Заменяем только подчеркивания на пробелы (слова внутри концепта)
        displayName = finalPart.replace(/_/g, ' ').split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
      }
      label.textContent = displayName;

      // Функция навигации к концепту
      const navigateToConcept = (e) => {
        e.stopPropagation();
        console.log(`[MINDMAP CLICK] Clicked on concept: ${conceptName}`);

        const firstSlideIndex = findFirstSlideWithConcept(conceptName);
        console.log(`[MINDMAP CLICK] Found slide index: ${firstSlideIndex}`);

        if (firstSlideIndex !== -1) {
          // Устанавливаем флаг навигации из карты
          const state = getCurrentState();
          if (state) {
            state.navigatedFromMap = true;
            state.lastSlideBeforeNavigation = getActiveSlide(state);
            console.log(`[MINDMAP CLICK] Set navigatedFromMap flag, last slide:`, state.lastSlideBeforeNavigation);
          }

          // Скрываем карту
          const knowledgeMapCloseButton = document.querySelector('#kmClose');
          console.log(`[MINDMAP CLICK] Knowledge map close button:`, knowledgeMapCloseButton);

          if (knowledgeMapCloseButton) {
            console.log(`[MINDMAP CLICK] Closing knowledge map`);
            knowledgeMapCloseButton.click();
          }

          // Переходим к слайду через hash
          console.log(`[MINDMAP CLICK] Navigating to slide ${firstSlideIndex} via hash`);

          // Переходим через изменение hash (слайд с номером firstSlideIndex + 1)
          const slideNumber = firstSlideIndex + 1;
          window.location.hash = `#${slideNumber}`;

          console.log(`[MINDMAP CLICK] Set hash to #${slideNumber}`);
        } else {
          console.log(`[MINDMAP CLICK] Slide not found for concept: ${conceptName}`);
        }
      };

      // Добавляем обработчик клика для круга и текста
      circle.style.cursor = 'pointer';
      circle.addEventListener('click', navigateToConcept);

      label.style.cursor = 'pointer';
      label.addEventListener('click', navigateToConcept);

      group.appendChild(circle);
      group.appendChild(label);
      svg.appendChild(group);

      // Добавляем в карту для отслеживания прогресса - используем ключ как есть
      console.log(`[MINDMAP] Создан узел: "${conceptName}" (отображение: "${displayName}") -> ключ: "${conceptName}"`);
      nodeByTag.set(conceptName, {
        x: pos.x, y: pos.y, circle, label, line: null
      });
    });

    // Сохраняем базовые позиции и углы для анимации
    const basePositions = new Map(positions);
    const baseAngles = new Map(angles);

    // Функция для обновления позиций с анимацией
    function updateOscillatingPositions() {
      const currentTime = Date.now();

      // Обновляем позиции всех узлов с колебаниями
      Array.from(basePositions.entries()).forEach(([conceptName, basePos]) => {
        if (conceptName === presentationTitle) return; // Пропускаем центральный узел

        const baseAngle = baseAngles.get(conceptName);
        if (baseAngle === undefined) return;

        // Генерируем колебание для этого узла
        const oscillationKey = conceptName.charCodeAt(0) + conceptName.length * 17;
        const amplitude = 0.035 + (oscillationKey % 7) * 0.004;
        const frequency = 1.3 + (oscillationKey % 11) * 0.1;
        const phase = (oscillationKey % 13) * 0.4;

        const oscillation = amplitude * Math.sin(frequency * currentTime / 2000 + phase);
        const currentAngle = baseAngle + oscillation;

        // Находим родителя для определения радиуса
        let parentName = null;
        let parentPos = { x: cx, y: cy };

        for (const [name, config] of Object.entries(mindMapStructure)) {
          if (config.children && config.children.includes(conceptName)) {
            parentName = name;
            if (parentName !== presentationTitle) {
              // Используем ТЕКУЩУЮ позицию родителя, а не базовую
              const parentCircle = svg.querySelector(`circle[data-km-tag="${parentName}"]`);
              if (parentCircle) {
                parentPos = {
                  x: parseFloat(parentCircle.getAttribute('cx')),
                  y: parseFloat(parentCircle.getAttribute('cy'))
                };
              } else {
                parentPos = basePositions.get(parentName) || parentPos;
              }
            }
            break;
          }
        }

        const level = levels.get(conceptName) || 1;
        const radius = level === 1 ? 126 : (level === 2 ? 90 : 70);

        // Вычисляем новую позицию с колебанием
        const newPos = {
          x: parentPos.x + radius * Math.cos(currentAngle),
          y: parentPos.y + radius * Math.sin(currentAngle)
        };

        // Обновляем узел - используем концепт-ключ как есть
        const circle = svg.querySelector(`circle[data-km-tag="${conceptName}"]`);
        const label = svg.querySelector(`text[data-km-tag="${conceptName}"]`);

        if (circle) {
          circle.setAttribute('cx', newPos.x);
          circle.setAttribute('cy', newPos.y);
        }
        if (label) {
          label.setAttribute('x', newPos.x);
          label.setAttribute('y', newPos.y);
        }

        // Обновляем связь (линию к родителю)
        if (parentName) {
          const line = svg.querySelector(`line[data-km-tag="${conceptName}"]`);
          if (line) {
            line.setAttribute('x1', parentPos.x);
            line.setAttribute('y1', parentPos.y);
            line.setAttribute('x2', newPos.x);
            line.setAttribute('y2', newPos.y);
          }
        }
      });
    }

    // Запускаем анимацию
    function animate() {
      updateOscillatingPositions();
      requestAnimationFrame(animate);
    }

    // Начинаем анимацию
    animate();

    return nodeByTag;
  }

  function normalizeTag(tag) {
    if (!tag) return '';
    // Заменяем пробелы на подчеркивания для корректного сравнения с CSS классами
    return tag.replace(/\s+/g, '_');
  }


  function extractSectionMetadata(section) {
    const tags = new Set();
    const links = [];

    if (!section) return { tags: [], links: [] };

    const walker = document.createTreeWalker(section, NodeFilter.SHOW_COMMENT, null);
    while (walker.nextNode()) {
      const raw = (walker.currentNode.nodeValue || '').trim();
      if (!raw) continue;

      const tagMatch = raw.match(/tags:\s*([a-z0-9_\-\/\,\s]+)/i);
      if (tagMatch) {
        tagMatch[1]
          .split(',')
          .map((token) => normalizeTag(token.trim()))
          .filter(Boolean)
          .forEach((value) => tags.add(value));
      }

      const linkMatch = raw.match(/links:\s*([a-z0-9_\-\/\,\s>]+)/i);
      if (linkMatch) {
        linkMatch[1]
          .split(',')
          .map((token) => token.trim())
          .filter(Boolean)
          .forEach((pair) => {
            const [rawA, rawB] = pair.split('>').map((token) => normalizeTag(token.trim()));
            if (rawA && rawB) links.push([rawA, rawB]);
          });
      }
    }

    section.className.split(/\s+/).forEach((cls) => {
      if (cls.startsWith('tags_')) {
        cls.replace(/^tags_/, '')
          .split('_')
          .map((token) => normalizeTag(token.trim()))
          .filter(Boolean)
          .forEach((value) => tags.add(value));
      }
      // Извлекаем концепты из классов concept_*
      if (cls.startsWith('concept_')) {
        const concept = cls.replace(/^concept_/, '').replace(/_/g, ' ');
        const normalizedConcept = normalizeTag(concept);
        tags.add(normalizedConcept);
        console.log(`Извлечен концепт из класса: "${cls}" -> "${concept}" -> "${normalizedConcept}"`);
      }
    });

    // data-topic используется только для топиков, не для концептов

    return {
      tags: Array.from(tags),
      links,
    };
  }

  function getSection(slide) {
    return slide.querySelector('foreignObject > section');
  }

  function buildState(slides, dom) {
    return {
      slides,
      dom,
      slideTags: new Map(),
      userLinkSet: new Set(CONFIG.defaultRelations.map((pair) => pair.join('>'))),
      userLinks: [],
      nodeByTag: null,
      mask: null,
      outlines: [],
      labels: [],
      revealedCells: new Set(),
      revealedTags: new Set(),
      cellOwners: new Map(),
      currentTab: CONFIG.tabOrder[0],
      fsContainer: null,
      suppressSave: false,
      // Новые переменные для отслеживания навигации
      navigatedFromMap: false,
      lastSlideBeforeNavigation: null,
      navigationTimer: null,
    };
  }

  function extractShortLabelsFromClasses() {
    // Ищем все CSS классы с паттерном concept_*$SHORT
    console.log('[LABELS] START - Начинаем извлечение коротких меток');
    const slides = Array.from(document.querySelectorAll('svg.bespoke-marp-slide'));
    console.log(`[LABELS] Найдено слайдов: ${slides.length}`, slides);

    if (slides.length === 0) {
      console.log('[LABELS] WARNING - Слайды не найдены! Пытаемся альтернативные селекторы...');
      const altSlides = Array.from(document.querySelectorAll('section'));
      console.log(`[LABELS] Альтернативный поиск: найдено section элементов: ${altSlides.length}`);
    }
    slides.forEach((slide, i) => {
      const section = slide.querySelector('foreignObject > section');
      if (!section) return;

      const conceptClasses = Array.from(section.classList).filter(cls => cls.startsWith('concept_'));
      if (conceptClasses.length > 0) {
        console.log(`[LABELS] Слайд ${i}: концепты =`, conceptClasses);
        console.log(`[LABELS] Слайд ${i}: все классы =`, Array.from(section.classList));
      }

      Array.from(section.classList).forEach(cls => {
        if (cls.startsWith('concept_')) {
          // Ищем паттерн concept_name$ABBREVIATION
          const dollarMatch = cls.match(/^concept_(.+)\$([A-Z]{2,8})$/);
          if (dollarMatch) {
            const conceptName = dollarMatch[1]; // Название концепта без concept_ и $ABBREV
            const shortLabel = dollarMatch[2];  // Аббревиатура после $
            const norm = normalizeTag(conceptName);
            CONFIG.tagShortLabels[norm] = shortLabel;
            console.log(`[LABELS] Извлечена короткая подпись из $: ${norm} -> ${shortLabel} (из ${cls})`);
          } else {
            // Старая логика для дефисов (для совместимости)
            const parts = cls.split('-');
            if (parts.length >= 2) {
              const lastPart = parts[parts.length - 1];
              // Сокращение: только заглавные буквы (2-8 символов)
              if (/^[A-Z]{2,8}$/.test(lastPart)) {
                const conceptPart = parts.slice(0, -1).join('-');
                const shortLabel = lastPart;
                if (conceptPart && shortLabel) {
                  const conceptName = conceptPart.replace(/^concept_/, '');
                  const norm = normalizeTag(conceptName);
                  CONFIG.tagShortLabels[norm] = shortLabel;
                  console.log(`[LABELS] Извлечена короткая подпись из дефиса: ${norm} -> ${shortLabel}`);
                }
              }
            } else {
              console.log(`[LABELS] Концепт без сокращения: ${cls}`);
            }
          }
        }
      });
    });
  }

  function collectMetadata(state) {
    state.slides.forEach((slide) => {
      const section = getSection(slide);
      const meta = extractSectionMetadata(section);
      state.slideTags.set(slide, meta.tags);
      meta.links.forEach((pair) => state.userLinkSet.add(pair.join('>')));
    });
    state.userLinks = Array.from(state.userLinkSet).map((key) => key.split('>'));
  }

  function initializeTagToCellsFromSlides(state) {
    if (CONFIG.tagToCells) return; // Уже инициализировано

    // Извлекаем короткие названия из CSS классов с суффиксом $
    extractShortLabelsFromClasses();

    // Определяем корневой концепт динамически
    let rootConcept = null;
    const firstSlide = document.querySelector('svg.bespoke-marp-slide');
    if (firstSlide) {
      const firstSection = firstSlide.querySelector('foreignObject > section');
      if (firstSection) {
        const conceptClass = Array.from(firstSection.classList).find(cls => cls.startsWith('concept_'));
        if (conceptClass) {
          rootConcept = normalizeTag(conceptClass.replace(/^concept_/, ''));
        }
      }
    }

    // Собираем все уникальные теги из слайдов
    const allSlideTags = new Set();
    state.slideTags.forEach(tags => {
      tags.forEach(tag => {
        const norm = normalizeTag(tag);
        // Убираем сокращения из тега (последняя часть если все заглавные)
        const parts = norm.split('-');
        const lastPart = parts[parts.length - 1];
        let cleanedTag = norm;
        if (parts.length > 1 && /^[A-Z]+$/.test(lastPart)) {
          cleanedTag = parts.slice(0, -1).join('-');
        }

        // Применяем маппинг составных тегов
        const tagMapping = {
          'authorization-rbac': ['authorization', 'rbac'],
          'architecture': ['authorization', 'admission']
        };
        const hexTags = tagMapping[cleanedTag] || [cleanedTag];
        hexTags.forEach(hexTag => {
          // Исключаем корневой концепт из hex-карты
          if (hexTag !== rootConcept) {
            allSlideTags.add(hexTag);
          }
        });
      });
    });

    const hexTags = Array.from(allSlideTags);
    console.log('[INIT] Корневой концепт (исключен):', rootConcept);
    console.log('[INIT] Найденные hex-теги из слайдов:', hexTags);

    const totalCells = CONFIG.hexLayout.length;
    const allCells = Array.from({length: totalCells}, (_, i) => i);

    // Перемешиваем случайно (Fisher-Yates)
    for (let i = allCells.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [allCells[i], allCells[j]] = [allCells[j], allCells[i]];
    }

    const cellsPerTag = Math.floor(totalCells / hexTags.length);
    const remainderCells = totalCells % hexTags.length;
    const result = {};

    let currentStart = 0;
    hexTags.forEach((tag, idx) => {
      // Первые remainderCells тегов получают дополнительную ячейку
      const extraCell = idx < remainderCells ? 1 : 0;
      const cellsForThisTag = cellsPerTag + extraCell;

      result[tag] = allCells.slice(currentStart, currentStart + cellsForThisTag);
      currentStart += cellsForThisTag;
    });

    CONFIG.tagToCells = result;
    console.log('[INIT] Распределение ячеек создано для реальных тегов:', result);
  }

  function drawMindLinks(state) {
    const svg = state.dom.mindSvg;
    state.userLinks.forEach(([a, b]) => {
      const nodeA = state.nodeByTag.get(a);
      const nodeB = state.nodeByTag.get(b);
      if (!nodeA || !nodeB) return;
      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.setAttribute('x1', nodeA.x);
      line.setAttribute('y1', nodeA.y);
      line.setAttribute('x2', nodeB.x);
      line.setAttribute('y2', nodeB.y);
      line.dataset.kmKey = `${a}>${b}`;
      line.setAttribute('class', 'mm-link');
      svg.insertBefore(line, svg.firstChild);
    });
  }

  function populateLegend(dom) {
    const container = dom.legend;
    container.innerHTML = '';
    container.style.display = 'none'; // Скрываем legend
    return; // Не создаем чипы концептов
    Object.keys(CONFIG.tagToCells).forEach((tag) => {
      const chip = document.createElement('span');
      chip.className = 'know-chip';
      chip.dataset.kmTag = tag;
      chip.textContent = CONFIG.tagLabels[tag] || tag;
      container.appendChild(chip);
    });
  }

  // Test function to manually trigger debugging
  function findFirstSlideWithConcept(conceptName) {
    // Ищем первый слайд, содержащий данный концепт
    const slides = document.querySelectorAll('svg.bespoke-marp-slide');
    console.log(`[FIND SLIDE] Looking for concept: "${conceptName}", total slides: ${slides.length}`);

    for (let i = 0; i < slides.length; i++) {
      const slide = slides[i];
      const section = slide.querySelector('foreignObject > section');
      if (section) {
        const conceptClasses = Array.from(section.classList).filter(cls => cls.startsWith('concept_'));

        if (conceptClasses.length > 0) {
          console.log(`[FIND SLIDE] Slide ${i} has concepts:`, conceptClasses);
        }

        for (const conceptClass of conceptClasses) {
          let extractedConcept = conceptClass.replace(/^concept_/, '');
          // Убираем $ABBREVIATION суффиксы для сравнения (как в mindmap структуре)
          extractedConcept = extractedConcept.replace(/\$[A-Z]{2,8}$/, '');
          const normalizedConcept = normalizeTag(extractedConcept);

          // Убираем сокращение для сравнения
          const parts = normalizedConcept.split('-');
          const lastPart = parts[parts.length - 1];
          let cleanedConcept = normalizedConcept;
          if (parts.length > 1 && /^[A-Z]+$/.test(lastPart)) {
            cleanedConcept = parts.slice(0, -1).join('-');
          }

          console.log(`[FIND SLIDE] Slide ${i}: "${extractedConcept}" -> "${normalizedConcept}" -> "${cleanedConcept}"`);

          // Нормализуем искомый концепт для сравнения
          const normalizedSearchConcept = normalizeTag(conceptName);

          // Сравниваем с искомым концептом
          if (cleanedConcept === normalizedSearchConcept) {
            console.log(`[FIND SLIDE] Found match at slide ${i}!`);
            return i;
          }
        }
      }
    }

    console.log(`[FIND SLIDE] No slide found for concept: "${conceptName}"`);
    return -1; // Не найден
  }

  window.debugHexCoverage = function() {
    const state = getCurrentState();
    const totalCells = CONFIG.hexLayout.length;
    const revealedCount = state.revealedCells.size;
    const unrevealedCount = totalCells - revealedCount;

    console.log(`[HEX COVERAGE] Total cells: ${totalCells}, Revealed: ${revealedCount}, Unrevealed: ${unrevealedCount}`);

    if (unrevealedCount > 0) {
      const unrevealed = [];
      for (let i = 0; i < totalCells; i++) {
        if (!state.revealedCells.has(i)) {
          unrevealed.push(i);
        }
      }
      console.log(`[HEX COVERAGE] Unrevealed cells:`, unrevealed);

      // Проверим, какие теги должны были покрыть эти ячейки
      Object.entries(CONFIG.tagToCells).forEach(([tag, cells]) => {
        const unrevealedForTag = cells.filter(cell => !state.revealedCells.has(cell));
        if (unrevealedForTag.length > 0) {
          console.log(`[HEX COVERAGE] Tag "${tag}" has ${unrevealedForTag.length} unrevealed cells:`, unrevealedForTag);
        }
      });
    }
  };

  function revealForTags(state, tags) {
    console.log(`[REVEAL] Обрабатываем теги:`, tags);
    let changed = false;
    tags.forEach((tag) => {
      const norm = normalizeTag(tag);
      console.log(`[REVEAL] Обрабатываем тег: ${tag} -> ${norm}`);

      // Убираем сокращения из тега (последняя часть если все заглавные)
      const parts = norm.split('-');
      const lastPart = parts[parts.length - 1];
      let cleanedTag = norm;
      if (parts.length > 1 && /^[A-Z]+$/.test(lastPart)) {
        cleanedTag = parts.slice(0, -1).join('-');
      }

      // Маппинг составных тегов к основным hex-тегам
      const tagMapping = {
        'authorization-rbac': ['authorization', 'rbac'],
        'architecture': ['authorization', 'admission']
      };

      const hexTags = tagMapping[cleanedTag] || [cleanedTag];
      console.log(`[HEX DEBUG] Processing tag: ${tag} -> norm: ${norm} -> hexTags:`, hexTags);

      // Исключаем корневой концепт из hex-карты (определяется динамически)
      const filteredHexTags = hexTags.filter(tag => {
        // Получаем корневой концепт из первого слайда
        const firstSlide = document.querySelector('svg.bespoke-marp-slide');
        if (firstSlide) {
          const firstSection = firstSlide.querySelector('foreignObject > section');
          if (firstSection) {
            const conceptClass = Array.from(firstSection.classList).find(cls => cls.startsWith('concept_'));
            if (conceptClass) {
              const rootConcept = normalizeTag(conceptClass.replace(/^concept_/, ''));
              return tag !== rootConcept;
            }
          }
        }
        return true;
      });

      console.log(`[HEX DEBUG] Filtered hex tags:`, filteredHexTags);

      filteredHexTags.forEach(hexTag => {
        console.log(`[HEX DEBUG] Processing hexTag: ${hexTag}`);
        const hexCells = CONFIG.tagToCells[hexTag] || [];
        console.log(`[HEX DEBUG] Cells for ${hexTag}:`, hexCells);
        let hexOpened = false;
        hexCells.forEach((index) => {
          if (!state.revealedCells.has(index)) {
            state.revealedCells.add(index);
            hexOpened = true;
            changed = true;
          }
          state.cellOwners.set(index, hexTag);
        });
        if (hexOpened) {
          state.revealedTags.add(hexTag);
          console.log(`[KM] Добавлен hex-концепт: ${hexTag}`);
        } else {
          console.log(`[HEX DEBUG] Tag ${hexTag} already revealed or no cells`);
        }
      });

      // Для MindMap: активируем концепты убирая сокращения из ключей
      console.log(`[DEBUG] Processing MindMap for tag: ${norm}`);
      console.log(`[DEBUG] Original tag: ${tag}`);
      const mindMapParts = norm.split('-');
      console.log(`[DEBUG] Tag parts:`, mindMapParts);

      // Убираем сокращение только из последнего сегмента
      const filteredParts = [...mindMapParts];
      if (filteredParts.length > 0) {
        const lastPart = filteredParts[filteredParts.length - 1];

        console.log(`[DEBUG] Last part: '${lastPart}'`);

        // Проверяем если есть суффикс $ABBREVIATION
        const dollarMatch = lastPart.match(/^(.+)\$([A-Z]{2,8})$/);
        if (dollarMatch) {
          console.log(`[DEBUG] Found $ABBREVIATION pattern: '${dollarMatch[0]}' -> base: '${dollarMatch[1]}', abbr: '${dollarMatch[2]}'`);

          // СОХРАНЯЕМ АББРЕВИАТУРУ в CONFIG.tagShortLabels для hex-карты
          const conceptKey = filteredParts.join('-');
          CONFIG.tagShortLabels[conceptKey] = dollarMatch[2];
          CONFIG.tagShortLabels[tag] = dollarMatch[2]; // Также для полного тега с $
          console.log(`[DEBUG] Сохранена аббревиатура: ${conceptKey} -> ${dollarMatch[2]}`);
          console.log(`[DEBUG] Сохранена аббревиатура для полного тега: ${tag} -> ${dollarMatch[2]}`);

          // Заменяем последнюю часть на базовую (без $ABBREVIATION)
          filteredParts[filteredParts.length - 1] = dollarMatch[1];
        } else {
          // Проверяем последний сегмент: если только заглавные буквы - это аббревиатура
          console.log(`[DEBUG] Checking if '${lastPart}' matches /^[A-Z]+$/: ${/^[A-Z]+$/.test(lastPart)}`);
          if (lastPart && /^[A-Z]+$/.test(lastPart)) {
            console.log(`[DEBUG] Removing abbreviation: ${lastPart}`);
            filteredParts.pop();
          } else {
            console.log(`[DEBUG] NOT removing '${lastPart}' because it's not all caps or has $suffix`);
          }
        }
      }
      console.log(`[DEBUG] Filtered parts:`, filteredParts);

      if (filteredParts.length > 0) {
        console.log(`[DEBUG] Processing MindMap hierarchy for ${filteredParts.join('-')}`);
        // Собираем все возможные пути в иерархии
        for (let i = 1; i <= filteredParts.length; i++) {
          const conceptPath = filteredParts.slice(0, i).join('-');
          console.log(`[DEBUG] Checking concept path: ${conceptPath}`);
          if (!state.revealedTags.has(conceptPath)) {
            state.revealedTags.add(conceptPath);
            changed = true;
            console.log(`[MINDMAP] Активирован концепт: ${conceptPath}`);
          } else {
            console.log(`[DEBUG] Concept path already revealed: ${conceptPath}`);
          }
        }
      } else {
        console.log(`[DEBUG] No filtered parts to process for MindMap`);
      }
    });

    if (changed) {
      render(state);
      if (!state.suppressSave) saveProgress(state);
    }
  }

  function render(state) {
    updateMask(state);
    updateHex(state);
    updateLegend(state);
    updateMeter(state);
    updateMindmap(state);
    if (state.fsContainer) renderFullScreen(state);
  }

  function updateMask(state) {
    const { mask } = state;

    // Удаляем все белые пути (кроме черного фона)
    while (mask.childNodes.length > 1) {
      mask.removeChild(mask.lastChild);
    }

    // Добавляем белые пути только для revealed ячеек
    state.revealedCells.forEach((index) => {
      const cell = CONFIG.hexLayout[index];
      if (!cell) return;

      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', buildHexPath(cell));
      path.setAttribute('class', 'reveal-mask-path');
      mask.appendChild(path);
    });
  }

  function updateHex(state) {

    state.outlines.forEach((outline, idx) => {
      const revealed = state.revealedCells.has(idx);
      const tag = state.cellOwners.get(idx);
      const classes = ['hex-outline'];
      if (revealed) classes.push('revealed');
      if (tag) classes.push(`tag-${tag.replace(/[^a-z0-9\-]/g, '')}`);
      outline.setAttribute('class', classes.join(' '));

      const label = state.labels[idx];
      if (tag) {
        // Показываем подпись только в первой открытой ячейке концепта
        const tagCells = CONFIG.tagToCells[tag] || [];
        const isFirstCellOfTag = tagCells.length > 0 && tagCells[0] === idx;


        if (isFirstCellOfTag && revealed) {
          // Ищем короткую метку, убирая суффиксы типа -authz, -rbac
          let baseTag = tag;
          // Убираем суффиксы если тег заканчивается на повторение последнего слова
          const parts = tag.split('-');
          if (parts.length >= 2) {
            const lastPart = parts[parts.length - 1];
            const secondLastPart = parts[parts.length - 2];
            if (lastPart === secondLastPart) {
              // authorization-authz -> authorization
              baseTag = parts.slice(0, -1).join('-');
            }
          }
          // Пробуем найти короткую метку по разным вариантам ключа
          let labelText = CONFIG.tagShortLabels[baseTag];
          if (!labelText) {
            // Пробуем с подчеркиваниями вместо пробелов
            const baseTagWithUnderscores = baseTag.replace(/ /g, '_');
            labelText = CONFIG.tagShortLabels[baseTagWithUnderscores];
          }
          if (!labelText) {
            console.log(`[HEX FALLBACK] Для тега "${tag}" не найдена аббревиатура в CONFIG.tagShortLabels:`, CONFIG.tagShortLabels);
            console.log(`[HEX FALLBACK] Используем fallback: "${tag.toUpperCase().slice(0, 4)}"`);
          }
          labelText = labelText || tag.toUpperCase().slice(0, 4);
          label.textContent = labelText;
          label.setAttribute('class', revealed ? 'hex-label show revealed' : 'hex-label show');

          // Добавляем навигацию по клику на hex-метку
          label.style.cursor = 'pointer';
          label.style.pointerEvents = 'auto';

          // Удаляем предыдущий обработчик, если есть
          label.removeEventListener('click', label._hexClickHandler);

          // Создаем новый обработчик
          label._hexClickHandler = (e) => {
            e.stopPropagation();
            console.log(`[HEX CLICK] Clicked on hex label: ${tag}`);

            const firstSlideIndex = findFirstSlideWithConcept(tag);
            console.log(`[HEX CLICK] Found slide index: ${firstSlideIndex}`);

            if (firstSlideIndex !== -1) {
              // Устанавливаем флаг навигации из карты
              const state = getCurrentState();
              if (state) {
                state.navigatedFromMap = true;
                state.lastSlideBeforeNavigation = getActiveSlide(state);
                console.log(`[HEX CLICK] Set navigatedFromMap flag, last slide:`, state.lastSlideBeforeNavigation);
              }

              // Скрываем карту
              const knowledgeMapCloseButton = document.querySelector('#kmClose');
              if (knowledgeMapCloseButton) {
                knowledgeMapCloseButton.click();
              }

              // Переходим к слайду через hash
              const slideNumber = firstSlideIndex + 1;
              window.location.hash = `#${slideNumber}`;
              console.log(`[HEX CLICK] Navigated to slide #${slideNumber}`);
            } else {
              console.log(`[HEX CLICK] Slide not found for hex tag: ${tag}`);
            }
          };

          label.addEventListener('click', label._hexClickHandler);
        } else {
          label.textContent = '';
          label.setAttribute('class', 'hex-label');
          label.style.cursor = 'default';
          label.style.pointerEvents = 'none';
          if (label._hexClickHandler) {
            label.removeEventListener('click', label._hexClickHandler);
            label._hexClickHandler = null;
          }
        }
      } else {
        label.textContent = '';
        label.setAttribute('class', 'hex-label');
        label.style.cursor = 'default';
        label.style.pointerEvents = 'none';
        if (label._hexClickHandler) {
          label.removeEventListener('click', label._hexClickHandler);
          label._hexClickHandler = null;
        }
      }
    });
  }

  function updateLegend(state) {
    const revealed = state.revealedTags;
    state.dom.legend.querySelectorAll('.know-chip').forEach((chip) => {
      chip.classList.toggle('done', revealed.has(chip.dataset.kmTag));
    });
  }

  function updateMeter(state) {
    const total = CONFIG.hexLayout.length || 1;
    const percentage = Math.round((state.revealedCells.size / total) * 100);
    state.dom.meterFill.style.width = `${percentage}%`;
    state.dom.meterPct.textContent = `${percentage}%`;
  }

  function updateMindmap(state) {
    state.nodeByTag.forEach((node, tag) => {
      const revealed = state.revealedTags.has(tag);
      node.circle.classList.toggle('revealed', revealed);
      if (node.line) {
        node.line.classList.toggle('revealed', revealed);
      }
    });
  }

  function renderMindMap(state, svgElement) {
    // Эта функция перерисовывает mindmap с актуальными изученными концептами
    console.log('[MINDMAP RENDER] Updating mindmap visualization');
    updateMindmap(state);
  }

  function saveProgress(state) {
    try {
      const payload = {
        tags: Array.from(state.revealedTags),
        tab: state.currentTab,
      };
      localStorage.setItem(CONFIG.storageKey, JSON.stringify(payload));
    } catch (_) {
      /* ignored */
    }
  }

  function loadProgress(state) {
    try {
      const raw = localStorage.getItem(CONFIG.storageKey);
      if (!raw) return;
      const data = JSON.parse(raw);
      if (data && Array.isArray(data.tags)) {
        console.log(`[LOAD PROGRESS] Загружаем сохраненные концепты: ${data.tags.length}`);
        state.suppressSave = true;

        // Загружаем все сохраненные концепты аккумулятивно
        data.tags.forEach(tag => {
          if (!state.revealedTags.has(tag)) {
            state.revealedTags.add(tag);
          }
        });

        // Применяем все загруженные теги
        revealForTags(state, data.tags);
        state.suppressSave = false;
      }
      if (data && typeof data.tab === 'string' && CONFIG.tabOrder.includes(data.tab)) {
        state.currentTab = data.tab;
      }
    } catch (_) {
      /* ignored */
    }
  }

  function setActiveTab(state, tab) {
    if (!CONFIG.tabOrder.includes(tab)) return;
    state.currentTab = tab;
    state.dom.tabButtons.forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.kmTab === tab);
    });
    state.dom.hexSvg.style.display = tab === 'hex' ? 'block' : 'none';
    state.dom.mindSvg.style.display = tab === 'mind' ? 'block' : 'none';

    // Обновляем mindmap при переключении на него с актуальными изученными концептами
    if (tab === 'mind') {
      console.log('[TAB SWITCH] Updating mindmap with current revealed concepts');
      renderMindMap(state, state.dom.mindSvg);
    }

    if (state.fsContainer) {
      state.fsContainer.querySelectorAll('.progress-tab').forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.kmTab === tab);
      });
      state.fsContainer.querySelectorAll('[data-km-view]').forEach((view) => {
        const active = view.dataset.kmView === tab;
        view.dataset.kmActive = active ? 'true' : 'false';
        view.style.display = active ? 'block' : 'none';

        // Обновляем mindmap в fullscreen режиме тоже
        if (active && tab === 'mind') {
          console.log('[TAB SWITCH] Updating fullscreen mindmap with current revealed concepts');
          const mindmapView = view.querySelector('svg');
          if (mindmapView) {
            renderMindMap(state, mindmapView);
          }
        }
      });
    }
    saveProgress(state);
  }

  function togglePanel(state) {
    state.dom.panel.classList.toggle('show');
  }

  function closePanel(state) {
    state.dom.panel.classList.remove('show');
  }

  function showReturnButton(state) {
    console.log('[RETURN BTN] Showing return button');
    state.dom.returnOverlay.classList.add('show');
  }

  function hideReturnButton(state) {
    console.log('[RETURN BTN] Hiding return button');
    state.dom.returnOverlay.classList.remove('show');

    // Очищаем таймер если он есть
    if (state.navigationTimer) {
      clearTimeout(state.navigationTimer);
      state.navigationTimer = null;
    }
  }

  function returnToMap(state) {
    console.log('[RETURN BTN] Returning to knowledge map');

    // Скрываем кнопку возврата
    hideReturnButton(state);

    // Возвращаемся к исходному слайду, если он есть
    if (state.lastSlideBeforeNavigation) {
      const slideIndex = state.slides.indexOf(state.lastSlideBeforeNavigation);
      console.log('[RETURN BTN] Returning to original slide index:', slideIndex);

      if (slideIndex !== -1) {
        // ВАЖНО: Активируем ВСЕ концепты до исходного слайда включительно
        console.log('[RETURN BTN] Marking all concepts up to original slide as learned');
        updateProgressUpToSlide(state, state.lastSlideBeforeNavigation);

        // Переходим к исходному слайду
        const slideNumber = slideIndex + 1;
        window.location.hash = `#${slideNumber}`;

        // Небольшая задержка для завершения навигации, затем открываем карту
        setTimeout(() => {
          console.log('[RETURN BTN] Opening knowledge map on original slide');
          if (!state.dom.panel.classList.contains('show')) {
            togglePanel(state);
          }
        }, 100);
      } else {
        // Если не нашли исходный слайд, просто открываем карту
        console.log('[RETURN BTN] Original slide not found, just opening map');
        togglePanel(state);
      }
    } else {
      // Если нет информации об исходном слайде, просто открываем карту
      console.log('[RETURN BTN] No original slide info, just opening map');
      togglePanel(state);
    }

    // Сбрасываем флаг навигации
    state.navigatedFromMap = false;
  }

  function isProgressSlide(slide) {
    const section = getSection(slide);
    return !!(section && section.classList.contains('page_progress'));
  }

  function isQuestionSlide(slide) {
    const section = getSection(slide);
    return !!(section && section.classList.contains('page_question'));
  }

  function getActiveSlide(state) {
    return state.slides.find((slide) => slide.classList.contains('bespoke-marp-active'))
      || state.slides.find((slide) => slide.getAttribute('aria-hidden') === 'false')
      || state.slides[0];
  }

  function updateProgressUpToSlide(state, currentSlide) {
    console.log('[PROGRESS UPDATE] Called with slide index:', state.slides.indexOf(currentSlide), 'navigatedFromMap:', state.navigatedFromMap);
    // Находим индекс текущего слайда
    const currentIndex = state.slides.indexOf(currentSlide);
    if (currentIndex === -1) return;

    // Собираем все теги до текущего слайда включительно
    const allTagsUpToSlide = new Set();
    for (let i = 0; i <= currentIndex; i++) {
      const tags = state.slideTags.get(state.slides[i]) || [];
      tags.forEach(tag => allTagsUpToSlide.add(tag));
    }

    // Если навигация из карты - только добавляем концепты (аккумулятивно)
    // Если обычная навигация - синхронизируем с текущим положением
    if (state.navigatedFromMap) {
      console.log('[PROGRESS UPDATE] Navigation from map - accumulative mode');
      // ВАЖНО: Только ДОБАВЛЯЕМ новые концепты, никогда не удаляем
      const newTagsToAdd = [];
      allTagsUpToSlide.forEach(tag => {
        if (!state.revealedTags.has(tag)) {
          newTagsToAdd.push(tag);
        }
      });
      newTagsToAdd.forEach(tag => state.revealedTags.add(tag));
    } else {
      console.log('[PROGRESS UPDATE] Normal navigation - sync mode');
      // Обычная навигация: полная синхронизация состояния с текущим положением

      // ПОЛНАЯ ПЕРЕСИНХРОНИЗАЦИЯ: очищаем все и заново строим
      state.revealedTags.clear();
      state.revealedCells.clear();
      state.cellOwners.clear();

      console.log('[PROGRESS UPDATE] Cleared all progress, rebuilding from slide 0 to', currentIndex);

      // Собираем все теги от начала до текущего слайда и применяем через revealForTags
      const allTagsToReveal = [];
      for (let i = 0; i <= currentIndex; i++) {
        const tags = state.slideTags.get(state.slides[i]) || [];
        tags.forEach(tag => {
          if (!allTagsToReveal.includes(tag)) {
            allTagsToReveal.push(tag);
          }
        });
      }

      console.log('[PROGRESS UPDATE] Revealing tags:', allTagsToReveal.length, allTagsToReveal);
      if (allTagsToReveal.length > 0) {
        revealForTags(state, allTagsToReveal);
      }

      // Дополнительное логирование для отладки
      console.log('[PROGRESS UPDATE] After rebuild - revealedTags:', Array.from(state.revealedTags));
      console.log('[PROGRESS UPDATE] After rebuild - revealedCells:', Array.from(state.revealedCells));
    }

    // Обновляем визуализацию карт
    updateHex(state);
    updateMindmap(state);
    updateMeter(state);
  }

  function handleSlideChange(state) {
    const slide = getActiveSlide(state);
    if (!slide) return;

    // Проверяем, является ли это возвратом из карты
    const isReturnFromMap = state.navigatedFromMap &&
                           state.lastSlideBeforeNavigation &&
                           slide === state.lastSlideBeforeNavigation;

    // Логика кнопки возврата к карте
    if (state.navigatedFromMap) {
      console.log('[SLIDE CHANGE] Navigated from map detected, showing return button');

      // Показываем кнопку возврата с небольшой задержкой для анимации
      setTimeout(() => {
        showReturnButton(state);
      }, 300);

      // Устанавливаем таймер для автоскрытия через 8 секунд
      state.navigationTimer = setTimeout(() => {
        if (state.navigatedFromMap) {
          console.log('[SLIDE CHANGE] Auto-hiding return button after timeout');
          state.navigatedFromMap = false;
          hideReturnButton(state);
        }
      }, 8000);
    } else {
      // Если навигация не из карты, скрываем кнопку
      hideReturnButton(state);
    }

    // Не пересчитываем прогресс только на страницах вопросов
    // Теперь updateProgressUpToSlide работает аккумулятивно и не удаляет концепты
    if (!isQuestionSlide(slide)) {
      console.log('[SLIDE CHANGE] Updating progress accumulatively');
      updateProgressUpToSlide(state, slide);
    }

    // Показываем overlay только на слайдах с вопросами
    if (isQuestionSlide(slide)) {
      state.dom.overlay.classList.add('show');
    } else {
      state.dom.overlay.classList.remove('show');
    }

    // Полноэкранный режим для progress слайдов
    if (isProgressSlide(slide)) {
      openFullScreen(state);
    } else {
      closeFullScreen(state);
    }
  }

  function openFullScreen(state) {
    if (state.fsContainer) return;
    const wrap = document.createElement('div');
    wrap.className = 'progress-fullscreen';
    wrap.innerHTML = `
      <div class="progress-map-wrap">
        <div class="progress-tabs">
          <button type="button" class="progress-tab" data-km-tab="hex">Hex-карта</button>
          <button type="button" class="progress-tab" data-km-tab="mind">Mindmap</button>
        </div>
        <div class="progress-stage"></div>
        <div class="progress-legend"></div>
      </div>
    `;
    document.body.appendChild(wrap);
    document.body.classList.add('progress-fullscreen-open');
    state.fsContainer = wrap;
    closePanel(state);
    wrap.querySelectorAll('.progress-tab').forEach((btn) => {
      btn.addEventListener('click', () => setActiveTab(state, btn.dataset.kmTab));
    });
    renderFullScreen(state);
    setActiveTab(state, state.currentTab);
  }

  function closeFullScreen(state) {
    if (!state.fsContainer) return;
    state.fsContainer.remove();
    state.fsContainer = null;
    document.body.classList.remove('progress-fullscreen-open');
  }

  function renderFullScreen(state) {
    if (!state.fsContainer) return;
    const stage = state.fsContainer.querySelector('.progress-stage');
    const legendSlot = state.fsContainer.querySelector('.progress-legend');
    stage.innerHTML = '';
    legendSlot.innerHTML = '';

    const hexClone = state.dom.hexSvg.cloneNode(true);
    updateCloneMask(hexClone, 'kmRevealMaskFS');
    hexClone.dataset.kmView = 'hex';

    const mindClone = state.dom.mindSvg.cloneNode(true);
    mindClone.dataset.kmView = 'mind';

    stage.appendChild(hexClone);
    stage.appendChild(mindClone);

    const legendClone = state.dom.legend.cloneNode(true);
    legendClone.classList.add('progress-legend-inner');
    legendSlot.appendChild(legendClone);
  }

  function updateCloneMask(svg, newId) {
    const mask = svg.querySelector('#kmRevealMask');
    if (!mask) return;
    mask.setAttribute('id', newId);
    svg.querySelectorAll('[mask="url(#kmRevealMask)"]').forEach((node) => {
      node.setAttribute('mask', `url(#${newId})`);
    });
  }

  function rotateFullScreenTab(state, delta) {
    const idx = CONFIG.tabOrder.indexOf(state.currentTab);
    const next = CONFIG.tabOrder[(idx + delta + CONFIG.tabOrder.length) % CONFIG.tabOrder.length];
    setActiveTab(state, next);
  }

  function bindEvents(state) {
    state.dom.toggleBtn.addEventListener('click', () => togglePanel(state));
    state.dom.closeBtn.addEventListener('click', () => closePanel(state));
    state.dom.returnBtn.addEventListener('click', () => returnToMap(state));
    state.dom.tabButtons.forEach((btn) => {
      btn.addEventListener('click', () => setActiveTab(state, btn.dataset.kmTab));
    });

    const scheduleUpdate = () => setTimeout(() => handleSlideChange(state), 20);

    // Функция для сброса флага при ручной навигации
    const resetNavigationFlag = () => {
      if (state.navigatedFromMap) {
        console.log('[MANUAL NAV] Manual navigation detected, resetting flag');
        state.navigatedFromMap = false;
        hideReturnButton(state);
      }
    };

    window.addEventListener('hashchange', scheduleUpdate);
    document.body.addEventListener('bespoke:slide', scheduleUpdate);
    document.addEventListener('click', scheduleUpdate);

    document.addEventListener('keydown', (event) => {
      // Закрытие карты по ESC
      if (event.key === 'Escape') {
        if (state.dom.panel.classList.contains('show')) {
          event.preventDefault();
          closePanel(state);
          return;
        }
      }

      if (state.fsContainer && (event.key === 'ArrowRight' || event.key === 'ArrowLeft')) {
        event.preventDefault();
        rotateFullScreenTab(state, event.key === 'ArrowRight' ? 1 : -1);
        return;
      }

      // Сбрасываем флаг навигации при ручном переходе клавишами
      if (['ArrowRight', 'ArrowLeft', 'PageDown', 'PageUp', ' '].includes(event.key)) {
        resetNavigationFlag();
        scheduleUpdate();
      }
    });

    window.addEventListener('resize', () => {
      if (state.fsContainer) renderFullScreen(state);
    });
  }

  function getCurrentState() {
    return window.__knowledgeMapState;
  }

  function init() {
    // НЕ удаляем прогресс из localStorage!
    try {
      // Только очистка устаревших ключей если нужно
      // localStorage.removeItem('knowledge-map.v1');
      // localStorage.removeItem('knowledge-map.v2');
      // localStorage.removeItem('knowledge-map.v3');
      // НЕ удаляем никакие данные из localStorage для сохранения прогресса
      // Object.keys(localStorage).forEach(key => {
      //   if (key.includes('knowledge') || key.includes('map') || key.includes('revealed')) {
      //     localStorage.removeItem(key);
      //   }
      // });
      console.log('[DEBUG] localStorage НЕ очищается - прогресс сохранен');
    } catch (e) {
      console.log('[DEBUG] Ошибка очистки localStorage:', e);
    }

    injectStyle();

    const slides = Array.from(document.querySelectorAll('svg.bespoke-marp-slide'));
    if (!slides.length) return;

    const dom = createOverlayDom();
    populateLegend(dom);

    const state = buildState(slides, dom);
    window.__knowledgeMapState = state;

    // Извлекаем короткие метки из CSS классов ПЕРЕД сбором метаданных
    console.log('[INIT] Вызываем extractShortLabelsFromClasses()');
    extractShortLabelsFromClasses();
    console.log('[INIT] CONFIG.tagShortLabels после извлечения:', CONFIG.tagShortLabels);

    // Сначала собираем метаданные для извлечения всех тегов
    collectMetadata(state);

    // Теперь можем создать распределение ячеек на основе реальных тегов
    initializeTagToCellsFromSlides(state);

    const { mask, outlines, labels } = createHexMap(dom);
    state.mask = mask;
    state.outlines = outlines;
    state.labels = labels;
    state.nodeByTag = createMindNodes(dom);
    drawMindLinks(state);
    loadProgress(state);
    render(state);
    setActiveTab(state, state.currentTab);
    bindEvents(state);
    handleSlideChange(state);

    window.__knowledgeMapInitialized = true;
  }

  waitForDomReady(init);
})();