#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const sharp = require('sharp');

class HTMLBundler {
    constructor(inputFile, outputFile) {
        this.inputFile = inputFile;
        this.outputFile = outputFile;
        this.baseDir = path.dirname(inputFile);
        this.processedUrls = new Set();
    }

    // Читаем файл и возвращаем содержимое
    readFile(filePath) {
        try {
            const fullPath = path.resolve(this.baseDir, filePath);
            return fs.readFileSync(fullPath, 'utf8');
        } catch (error) {
            console.warn(`Не удалось прочитать файл: ${filePath}`);
            return null;
        }
    }

    // Читаем файл как base64
    readFileAsBase64(filePath) {
        try {
            const fullPath = path.resolve(this.baseDir, filePath);
            const buffer = fs.readFileSync(fullPath);
            return buffer.toString('base64');
        } catch (error) {
            console.warn(`Не удалось прочитать файл: ${filePath}`);
            return null;
        }
    }

    // Определяем MIME тип по расширению файла
    getMimeType(filePath) {
        const ext = path.extname(filePath).toLowerCase();
        const mimeTypes = {
            '.png': 'image/png',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.gif': 'image/gif',
            '.svg': 'image/svg+xml',
            '.webp': 'image/webp',
            '.ico': 'image/x-icon',
            '.woff': 'font/woff',
            '.woff2': 'font/woff2',
            '.ttf': 'font/ttf',
            '.otf': 'font/otf',
            '.eot': 'application/vnd.ms-fontobject'
        };
        return mimeTypes[ext] || 'application/octet-stream';
    }

    // Проверяем, является ли URL внешней ссылкой
    isExternalUrl(url) {
        return url.startsWith('http://') || url.startsWith('https://') || url.startsWith('//');
    }

    // Анализируем CSS для извлечения background-image путей из style scoped
    extractCardImagePaths(document) {
        const cardImages = new Map();

        // Ищем все style элементы (включая обычные, не только scoped)
        const styleElements = document.querySelectorAll('style');

        for (const styleEl of styleElements) {
            const cssText = styleEl.textContent || '';

            // Паттерн для поиска CSS правил с background-image для карточек
            // Упрощенный поиск - ищем любые rules с page_cards_image и локальными изображениями
            const cardRules = cssText.match(/[^}]*page_cards_image[^}]*nth-of-type\((\d+)\)[^}]*background-image:[^}]*url\(['"]?(resources\/[^'")}]+)['"]?[^}]*}/g);

            if (cardRules) {
                for (const rule of cardRules) {
                    const numberMatch = rule.match(/nth-of-type\((\d+)\)/);
                    const urlMatch = rule.match(/url\(['"]?(resources\/[^'")}]+)['"]?\)/);

                    if (numberMatch && urlMatch) {
                        const cardNumber = parseInt(numberMatch[1]);
                        const imagePath = urlMatch[1];
                        cardImages.set(imagePath, cardNumber);
                        console.log(`Найдено изображение карточки ${cardNumber}: ${imagePath}`);
                    }
                }
            }

            // Также проверяем page_cards_image_four
            const fourCardRules = cssText.match(/[^}]*page_cards_image_four[^}]*nth-of-type\((\d+)\)[^}]*background-image:[^}]*url\(['"]?(resources\/[^'")}]+)['"]?[^}]*}/g);

            if (fourCardRules) {
                for (const rule of fourCardRules) {
                    const numberMatch = rule.match(/nth-of-type\((\d+)\)/);
                    const urlMatch = rule.match(/url\(['"]?(resources\/[^'")}]+)['"]?\)/);

                    if (numberMatch && urlMatch) {
                        const cardNumber = parseInt(numberMatch[1]);
                        const imagePath = urlMatch[1];
                        cardImages.set(imagePath, cardNumber);
                        console.log(`Найдено изображение карточки (4) ${cardNumber}: ${imagePath}`);
                    }
                }
            }
        }

        return cardImages;
    }

    // Анализируем CSS элемента для определения размера на основе Marp классов
    analyzeElementContext(element, document) {
        let context = '';
        let gridColumns = 1;

        // Проходим по родительским элементам
        let current = element;
        while (current && current.parentElement) {
            current = current.parentElement;

            // Получаем className и tagName
            const className = String(current.className || '');
            const tagName = current.tagName.toLowerCase();

            // === СПЕЦИФИЧНЫЕ ПРОВЕРКИ ДЛЯ MARP ПРЕЗЕНТАЦИЙ ===

            // Проверяем Marp card layouts
            if (className.includes('page_cards_image_four')) {
                gridColumns = 4;
                console.log(`Найден Marp layout: page_cards_image_four -> 4 колонки`);
                break;
            }

            if (className.includes('page_cards_image') && !className.includes('four')) {
                gridColumns = 3;
                console.log(`Найден Marp layout: page_cards_image -> 3 колонки`);
                break;
            }

            if (className.includes('page_cards')) {
                gridColumns = 2;
                console.log(`Найден Marp layout: page_cards -> 2 колонки`);
                break;
            }

            if (className.includes('page_twocolumn')) {
                gridColumns = 2;
                console.log(`Найден Marp layout: page_twocolumn -> 2 колонки`);
                break;
            }

            // === ОБЩИЕ ПРОВЕРКИ ДЛЯ ДРУГИХ ПРЕЗЕНТАЦИЙ ===

            // Проверяем, находится ли изображение в UL внутри section с классом course_page
            if (className.includes('course_page') && tagName === 'section') {
                // Ищем родительский ul
                let ulParent = element.parentElement;
                while (ulParent && ulParent.tagName.toLowerCase() !== 'ul') {
                    ulParent = ulParent.parentElement;
                }

                if (ulParent && ulParent.tagName.toLowerCase() === 'ul') {
                    // По CSS правилу section.course_page ul имеет grid-template-columns:repeat(4, 1fr)
                    gridColumns = 4;
                    console.log(`Найден grid layout: section.course_page ul -> 4 колонки`);
                    break;
                }
            }

            // Проверяем инлайн стили
            const styles = current.getAttribute('style') || '';
            if (styles.includes('grid-template-columns')) {
                const match = styles.match(/grid-template-columns\s*:\s*repeat\((\d+)/);
                if (match) {
                    gridColumns = parseInt(match[1]);
                    console.log(`Найден инлайн grid: repeat(${gridColumns}) -> ${gridColumns} колонок`);
                    break;
                }
                // Также проверяем паттерн "1fr 1fr 1fr ..."
                const frMatch = styles.match(/grid-template-columns\s*:\s*((?:1fr\s*)+)/);
                if (frMatch) {
                    gridColumns = frMatch[1].split('1fr').length - 1;
                    console.log(`Найден fr grid: ${gridColumns} колонок`);
                    break;
                }
            }
        }

        if (gridColumns >= 4) {
            context = 'four_columns';
        } else if (gridColumns === 3) {
            context = 'three_columns';
        } else if (gridColumns === 2) {
            context = 'two_columns';
        }

        return { context, gridColumns };
    }

    // Определяем целевой размер изображения на основе его использования
    getTargetImageSize(filePath, context = '', gridColumns = 1) {
        const filename = path.basename(filePath).toLowerCase();

        // Определяем размеры на основе количества колонок в grid
        // Для Marp презентаций: слайды 960x540px (real size)

        // Изображения в 4-колоночной сетке (самые маленькие)
        if (gridColumns >= 4 || context.includes('four_columns')) {
            return { width: 200, height: 150 }; // ~1/5 от ширины слайда
        }

        // Изображения в 3-колоночной сетке
        if (gridColumns === 3 || context.includes('three_columns')) {
            return { width: 280, height: 210 }; // ~1/3 от ширины слайда
        }

        // Средние изображения для 2 колонки
        if (gridColumns === 2 || context.includes('two_columns')) {
            return { width: 400, height: 300 }; // ~1/2 от ширины слайда
        }

        // Фоновые изображения hex-карты (уменьшаем значительно)
        if (filename.includes('kubernetes') && (filename.includes('background') || filename.includes('hex'))) {
            return { width: 600, height: 400 }; // Достаточно для фона
        }

        // Диаграммы и схемы (средний размер)
        if (filename.includes('diagram') || filename.includes('schema') || filename.includes('chart')) {
            return { width: 600, height: 450 };
        }

        // Полноразмерные изображения (по умолчанию)
        return { width: 800, height: 600 }; // Максимальный размер для слайдов
    }

    // Изменяем размер изображения с помощью Sharp
    async resizeImage(filePath, targetSize) {
        try {
            const fullPath = path.resolve(this.baseDir, filePath);
            const ext = path.extname(filePath).toLowerCase();

            let sharpImage = sharp(fullPath)
                .resize(targetSize.width, targetSize.height, {
                    fit: 'inside', // Сохраняем пропорции
                    withoutEnlargement: true // Не увеличиваем маленькие изображения
                });

            // Сохраняем оригинальный формат
            if (ext === '.png') {
                sharpImage = sharpImage.png({ quality: 85 });
            } else {
                sharpImage = sharpImage.jpeg({ quality: 85 });
            }

            const buffer = await sharpImage.toBuffer();
            return buffer.toString('base64');
        } catch (error) {
            console.warn(`Не удалось изменить размер изображения: ${filePath}`, error.message);
            // Fallback: читаем оригинальное изображение
            return this.readFileAsBase64(filePath);
        }
    }

    // Обрабатываем CSS и встраиваем в него ресурсы
    async processCss(cssContent) {
        // Обрабатываем url() в CSS
        const urlMatches = [...cssContent.matchAll(/url\(['"]?([^'")]+)['"]?\)/g)];
        let processedCss = cssContent;

        for (const match of urlMatches) {
            const [fullMatch, url] = match;

            if (this.isExternalUrl(url) || this.processedUrls.has(url)) {
                continue;
            }

            this.processedUrls.add(url);

            // Проверяем существование файла в разных местах
            const possiblePaths = [
                path.resolve(this.baseDir, url),
                path.resolve(this.baseDir, 'resources', url),
                path.resolve(this.baseDir, '..', 'resources', url)
            ];

            let fullPath = null;
            for (const testPath of possiblePaths) {
                if (fs.existsSync(testPath)) {
                    fullPath = testPath;
                    break;
                }
            }

            if (!fullPath) {
                console.log(`CSS ресурс не найден: ${url} (проверены пути: ${possiblePaths.join(', ')})`);
                continue;
            }

            // Определяем размер и изменяем изображение
            const targetSize = this.getTargetImageSize(url, 'css_background');
            let base64;

            if (this.getMimeType(url).startsWith('image/')) {
                // Используем найденный путь для обработки изображения
                const tempBuffer = fs.readFileSync(fullPath);
                base64 = await sharp(tempBuffer)
                    .resize(targetSize.width, targetSize.height, { fit: 'cover' })
                    .jpeg({ quality: 85 })
                    .toBuffer()
                    .then(buffer => buffer.toString('base64'));
                console.log(`Обрабатываем фоновое изображение в CSS: ${url} (${targetSize.width}x${targetSize.height}) из ${fullPath}`);
            } else {
                base64 = fs.readFileSync(fullPath, 'base64');
            }

            if (base64) {
                const mimeType = url.toLowerCase().includes('.png') ? 'image/png' : 'image/jpeg';
                const replacement = `url(data:${mimeType};base64,${base64})`;
                processedCss = processedCss.replace(fullMatch, replacement);
            }
        }

        return processedCss;
    }

    // Обрабатываем JavaScript и встраиваем ресурсы
    async processJs(jsContent) {
        // Заменяем localStorage на sessionStorage для работы в file:// протоколе
        let processedJs = jsContent.replace(/localStorage/g, 'sessionStorage');

        // Паттерн для поиска строк с путями к файлам (resources/, assets/, images/, и т.д.)
        const resourcePattern = /(['"`])([^'"`]*(?:resources|assets|images|img|static)\/[^'"`]*\.(?:png|jpg|jpeg|gif|svg|webp|ico|woff|woff2|ttf|otf|eot))\1/gi;
        const matches = [...processedJs.matchAll(resourcePattern)];

        for (const match of matches) {
            const [fullMatch, quote, filePath] = match;

            if (this.isExternalUrl(filePath) || this.processedUrls.has(filePath)) {
                continue;
            }

            console.log(`Обрабатываем ресурс в JS: ${filePath}`);
            this.processedUrls.add(filePath);

            let base64;
            if (this.getMimeType(filePath).startsWith('image/')) {
                // Определяем размер изображения
                const targetSize = this.getTargetImageSize(filePath, 'javascript_resource');
                base64 = await this.resizeImage(filePath, targetSize);
                console.log(`Изменен размер изображения: ${filePath} (${targetSize.width}x${targetSize.height}), MIME: ${this.getMimeType(filePath)}`);
            } else {
                base64 = this.readFileAsBase64(filePath);
            }

            if (base64) {
                const mimeType = this.getMimeType(filePath);
                const replacement = `${quote}data:${mimeType};base64,${base64}${quote}`;
                processedJs = processedJs.replace(fullMatch, replacement);
                console.log(`Заменен путь в JS: ${filePath} -> data URI (${mimeType})`);
            }
        }

        return processedJs;
    }

    async bundle() {
        console.log(`Сборка HTML файла: ${this.inputFile}`);

        // Читаем исходный HTML
        const htmlContent = this.readFile(this.inputFile);
        if (!htmlContent) {
            throw new Error(`Не удалось прочитать файл: ${this.inputFile}`);
        }

        // Парсим HTML
        const dom = new JSDOM(htmlContent);
        const document = dom.window.document;

        // Обрабатываем CSS файлы
        const linkElements = document.querySelectorAll('link[rel="stylesheet"]');
        for (const link of linkElements) {
            const href = link.getAttribute('href');
            if (!href || this.isExternalUrl(href)) continue;

            console.log(`Обрабатываем CSS: ${href}`);
            const cssContent = this.readFile(href);
            if (cssContent) {
                const processedCss = await this.processCss(cssContent);
                const styleElement = document.createElement('style');
                styleElement.textContent = processedCss;
                link.parentNode.replaceChild(styleElement, link);
            }
        }

        // Обрабатываем JavaScript файлы
        const scriptElements = document.querySelectorAll('script[src]');
        for (const script of scriptElements) {
            const src = script.getAttribute('src');
            if (!src || this.isExternalUrl(src)) continue;

            console.log(`Обрабатываем JS: ${src}`);
            const jsContent = this.readFile(src);
            if (jsContent) {
                const processedJs = await this.processJs(jsContent);
                script.removeAttribute('src');
                script.textContent = processedJs;
            }
        }

        // Обрабатываем инлайн JavaScript скрипты
        const inlineScriptElements = document.querySelectorAll('script:not([src])');
        for (const script of inlineScriptElements) {
            const jsContent = script.textContent;
            if (jsContent && (jsContent.includes('resources/') || jsContent.includes('localStorage'))) {
                console.log(`Обрабатываем инлайн JS с ресурсами или localStorage`);
                const processedJs = await this.processJs(jsContent);
                script.textContent = processedJs;
            }
        }

        // Извлекаем пути к изображениям карточек из CSS для оптимизации
        const cardImages = this.extractCardImagePaths(document);
        console.log(`Найдено изображений карточек для оптимизации: ${cardImages.size}`);

        // Обрабатываем изображения
        const imgElements = document.querySelectorAll('img[src]');
        for (const img of imgElements) {
            const src = img.getAttribute('src');
            if (!src || this.isExternalUrl(src) || src.startsWith('data:')) continue;

            console.log(`Обрабатываем изображение: ${src}`);

            // Проверяем, является ли это изображением карточки из CSS
            if (cardImages.has(src)) {
                const cardNumber = cardImages.get(src);
                console.log(`Это изображение карточки ${cardNumber}, применяем оптимизацию размера`);

                // Определяем размер на основе номера карточки (3 или 4 колонки)
                const gridColumns = cardNumber <= 3 ? 3 : 4;
                const targetSize = this.getTargetImageSize(src, '', gridColumns);
                const base64 = await this.resizeImage(src, targetSize);

                if (base64) {
                    const mimeType = src.toLowerCase().includes('.png') ? 'image/png' : 'image/jpeg';
                    img.setAttribute('src', `data:${mimeType};base64,${base64}`);
                    console.log(`Оптимизировано изображение карточки: ${src} (${targetSize.width}x${targetSize.height})`);
                }
            } else {
                // Для остальных изображений - конвертируем в JPG для уменьшения размера
                // ИСКЛЮЧЕНИЕ: изображения, используемые в JavaScript, сохраняем в оригинальном формате
                if (!src || typeof src !== 'string') {
                    console.log(`Пропускаем невалидный src: ${src}`);
                    return;
                }
                const ext = path.extname(src).toLowerCase();
                const fullPath = path.resolve(this.baseDir, src);

                // Проверяем, используется ли это изображение в JavaScript (например, в знание-карте)
                const isJavaScriptResource = src.includes('knowledge_map_bg') || this.processedUrls.has(src);

                if ((ext === '.png' || ext === '.jpg' || ext === '.jpeg') && fs.existsSync(fullPath)) {
                    if (isJavaScriptResource && ext === '.png') {
                        // Сохраняем PNG формат для JavaScript ресурсов
                        console.log(`Сохраняем PNG формат для JavaScript ресурса: ${src}`);
                        const base64 = this.readFileAsBase64(src);
                        if (base64) {
                            const mimeType = this.getMimeType(src);
                            img.setAttribute('src', `data:${mimeType};base64,${base64}`);
                        }
                    } else {
                        // Обычная конвертация в JPG
                        console.log(`Конвертируем изображение в JPG: ${src}`);
                        try {
                            const jpegBuffer = await sharp(fullPath)
                                .jpeg({ quality: 85 })
                                .toBuffer();

                            const base64 = jpegBuffer.toString('base64');
                            const dataUri = `data:image/jpeg;base64,${base64}`;
                            img.setAttribute('src', dataUri);
                            console.log(`Конвертировано в JPG: ${src}`);
                        } catch (error) {
                            console.log(`Ошибка конвертации в JPG, используем оригинал: ${src}`);
                            const base64 = this.readFileAsBase64(src);
                            if (base64) {
                                const mimeType = this.getMimeType(src);
                                img.setAttribute('src', `data:${mimeType};base64,${base64}`);
                            }
                        }
                    }
                } else {
                    // SVG и другие форматы оставляем как есть
                    console.log(`Обычное изображение, встраиваем без изменения: ${src}`);
                    const base64 = this.readFileAsBase64(src);
                    if (base64) {
                        const mimeType = this.getMimeType(src);
                        img.setAttribute('src', `data:${mimeType};base64,${base64}`);
                    }
                }
            }
        }

        // Обрабатываем другие элементы с атрибутами src/href
        const elementsWithResources = document.querySelectorAll('[src], [href]');
        for (const element of elementsWithResources) {
            ['src', 'href'].forEach(attr => {
                const url = element.getAttribute(attr);
                if (!url || this.isExternalUrl(url) || url.startsWith('data:') || url.startsWith('#')) return;

                // Пропускаем уже обработанные элементы
                if (element.tagName === 'LINK' || element.tagName === 'SCRIPT' || element.tagName === 'IMG') return;

                console.log(`Обрабатываем ресурс: ${url}`);
                const base64 = this.readFileAsBase64(url);
                if (base64) {
                    const mimeType = this.getMimeType(url);
                    element.setAttribute(attr, `data:${mimeType};base64,${base64}`);
                }
            });
        }

        // Сохраняем результат
        const bundledHtml = dom.serialize();
        fs.writeFileSync(this.outputFile, bundledHtml, 'utf8');
        console.log(`Моно-HTML файл создан: ${this.outputFile}`);
    }
}

// Основная функция
async function main() {
    const args = process.argv.slice(2);

    if (args.length < 1 || args.length > 2) {
        console.log('Использование: node bundle-html.js <input.html> [output.html]');
        console.log('Примеры:');
        console.log('  node bundle-html.js index.html');
        console.log('  node bundle-html.js index.html bundled.html');
        process.exit(1);
    }

    const inputFile = args[0];
    const outputFile = args[1] || inputFile.replace('.html', '-bundled.html');

    if (!fs.existsSync(inputFile)) {
        console.error(`Файл не найден: ${inputFile}`);
        process.exit(1);
    }

    try {
        const bundler = new HTMLBundler(inputFile, outputFile);
        await bundler.bundle();
        console.log('Сборка завершена успешно!');
    } catch (error) {
        console.error('Ошибка при сборке:', error.message);
        process.exit(1);
    }
}

// Проверяем, запущен ли скрипт напрямую
if (require.main === module) {
    main();
}

module.exports = HTMLBundler;