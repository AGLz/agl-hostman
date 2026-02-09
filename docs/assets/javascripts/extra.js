// Extra JavaScript for AGL Hostman Documentation

document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    const tooltips = document.querySelectorAll('[title]');
    tooltips.forEach(tooltip => {
        tooltip.addEventListener('mouseenter', showTooltip);
        tooltip.addEventListener('mouseleave', hideTooltip);
    });

    // Initialize code copy buttons
    const codeBlocks = document.querySelectorAll('pre.md-code');
    codeBlocks.forEach(block => {
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-button';
        copyButton.textContent = 'Copy';
        copyButton.addEventListener('click', copyCode);
        block.appendChild(copyButton);
    });

    // Initialize interactive examples
    const examples = document.querySelectorAll('.interactive-example');
    examples.forEach(example => {
        initializeInteractiveExample(example);
    });

    // Initialize search enhancement
    enhanceSearch();

    // Initialize dark mode toggle
    initializeDarkMode();

    // Initialize API endpoint testing
    initializeApiTesting();
});

// Tooltip functionality
function showTooltip(e) {
    const tooltip = document.createElement('div');
    tooltip.className = 'tooltip';
    tooltip.textContent = e.target.getAttribute('title');
    tooltip.style.position = 'absolute';
    tooltip.style.background = '#333';
    tooltip.style.color = 'white';
    tooltip.style.padding = '5px 10px';
    tooltip.style.borderRadius = '4px';
    tooltip.style.zIndex = '1000';
    tooltip.style.fontSize = '14px';
    tooltip.style.pointerEvents = 'none';

    const rect = e.target.getBoundingClientRect();
    tooltip.style.left = rect.left + 'px';
    tooltip.style.top = (rect.bottom + 5) + 'px';

    document.body.appendChild(tooltip);
    e.target.setAttribute('data-tooltip', tooltip);
}

function hideTooltip(e) {
    const tooltip = e.target.getAttribute('data-tooltip');
    if (tooltip) {
        tooltip.remove();
        e.target.removeAttribute('data-tooltip');
    }
}

// Code copy functionality
function copyCode(e) {
    const button = e.target;
    const codeBlock = button.parentElement;
    const code = codeBlock.textContent.trim();

    navigator.clipboard.writeText(code).then(() => {
        const originalText = button.textContent;
        button.textContent = 'Copied!';
        button.style.backgroundColor = '#28a745';

        setTimeout(() => {
            button.textContent = originalText;
            button.style.backgroundColor = '';
        }, 2000);
    });
}

// Interactive example initialization
function initializeInteractiveExample(example) {
    const runButton = example.querySelector('.run-button');
    const output = example.querySelector('.output');
    const resetButton = example.querySelector('.reset-button');

    if (runButton) {
        runButton.addEventListener('click', () => {
            const exampleCode = example.querySelector('pre code').textContent;

            try {
                // Execute example code (simplified for demo)
                eval(exampleCode);

                output.innerHTML = '<div class="success-message">✓ Example executed successfully</div>';
            } catch (error) {
                output.innerHTML = `<div class="error-message">✗ Error: ${error.message}</div>`;
            }
        });
    }

    if (resetButton) {
        resetButton.addEventListener('click', () => {
            output.innerHTML = '';
        });
    }
}

// Search enhancement
function enhanceSearch() {
    const searchInput = document.querySelector('.md-search__input');
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const searchTerm = e.target.value.toLowerCase();

            if (searchTerm.length > 2) {
                highlightSearchResults(searchTerm);
            } else {
                clearHighlight();
            }
        });
    }
}

function highlightSearchResults(searchTerm) {
    const content = document.querySelector('.md-content');
    const text = content.textContent;

    const regex = new RegExp(searchTerm, 'gi');
    const matches = text.match(regex);

    if (matches) {
        const highlightedText = text.replace(regex, `<mark>$&</mark>`);
        // Note: This is a simplified approach. In a real implementation,
        // you'd want to use a proper highlighting library
    }
}

function clearHighlight() {
    const marks = document.querySelectorAll('mark');
    marks.forEach(mark => {
        mark.outerHTML = mark.textContent;
    });
}

// Dark mode toggle
function initializeDarkMode() {
    const darkModeToggle = document.querySelector('.dark-mode-toggle');
    if (darkModeToggle) {
        darkModeToggle.addEventListener('click', () => {
            document.body.classList.toggle('dark-mode');

            // Store preference
            const isDark = document.body.classList.contains('dark-mode');
            localStorage.setItem('darkMode', isDark);
        });

        // Load saved preference
        const savedDarkMode = localStorage.getItem('darkMode');
        if (savedDarkMode === 'true') {
            document.body.classList.add('dark-mode');
        }
    }
}

// API testing functionality
function initializeApiTesting() {
    const testButtons = document.querySelectorAll('.api-test-button');
    testButtons.forEach(button => {
        button.addEventListener('click', (e) => {
            const endpoint = e.target.dataset.endpoint;
            const method = e.target.dataset.method;

            testApiEndpoint(endpoint, method);
        });
    });
}

function testApiEndpoint(endpoint, method) {
    const output = document.querySelector('.api-test-output');
    const button = event.target;

    button.disabled = true;
    button.textContent = 'Testing...';

    // Simulate API call
    setTimeout(() => {
        const response = {
            status: 200,
            data: {
                message: 'API call successful',
                timestamp: new Date().toISOString(),
                endpoint: endpoint
            }
        };

        output.innerHTML = `
            <div class="api-test-success">
                <h4>Response:</h4>
                <pre>${JSON.stringify(response, null, 2)}</pre>
            </div>
        `;

        button.disabled = false;
        button.textContent = 'Test Again';
    }, 1000);
}

// Utility functions
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString();
}

// Performance monitoring
function setupPerformanceMonitoring() {
    if ('performance' in window) {
        const observer = new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
                console.log('Performance entry:', entry);
            }
        });

        observer.observe({ entryTypes: ['navigation', 'resource', 'paint'] });
    }
}

// Initialize performance monitoring if available
if (window.performance) {
    setupPerformanceMonitoring();
}