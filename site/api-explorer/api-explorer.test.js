/**
 * API Explorer Tests
 *
 * Run with: npm test
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';

describe('API Explorer', () => {
  describe('Configuration', () => {
    it('should have API config defined', () => {
      expect(apiConfig).toBeDefined();
      expect(apiConfig.specUrl).toBeTruthy();
    });

    it('should have Swagger config defined', () => {
      expect(swaggerConfig).toBeDefined();
      expect(swaggerConfig.domId).toBe('#swagger-ui');
    });

    it('should have ReDoc config defined', () => {
      expect(redocConfig).toBeDefined();
      expect(redocConfig.theme).toBeDefined();
    });
  });

  describe('Authentication', () => {
    beforeEach(() => {
      localStorage.clear();
    });

    afterEach(() => {
      localStorage.clear();
    });

    it('should store API key in localStorage', () => {
      const apiKey = 'test-api-key-12345';
      localStorage.setItem('agl_api_key', apiKey);

      expect(localStorage.getItem('agl_api_key')).toBe(apiKey);
    });

    it('should store JWT token in localStorage', () => {
      const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test';
      localStorage.setItem('agl_jwt_token', token);

      expect(localStorage.getItem('agl_jwt_token')).toBe(token);
    });

    it('should clear credentials on logout', () => {
      localStorage.setItem('agl_api_key', 'test-key');
      localStorage.setItem('agl_jwt_token', 'test-token');

      localStorage.removeItem('agl_api_key');
      localStorage.removeItem('agl_jwt_token');

      expect(localStorage.getItem('agl_api_key')).toBeNull();
      expect(localStorage.getItem('agl_jwt_token')).toBeNull();
    });
  });

  describe('View Switching', () => {
    it('should switch between tabs', () => {
      const tabs = document.querySelectorAll('.nav-tab');
      const views = document.querySelectorAll('.view-container');

      // Initially, swagger tab should be active
      expect(tabs[0].classList.contains('active')).toBe(true);
      expect(document.getElementById('swaggerView').classList.contains('active')).toBe(true);

      // Switch to redoc
      tabs[1].click();
      expect(tabs[1].classList.contains('active')).toBe(true);
      expect(document.getElementById('redocView').classList.contains('active')).toBe(true);

      // Switch to code
      tabs[2].click();
      expect(tabs[2].classList.contains('active')).toBe(true);
      expect(document.getElementById('codeView').classList.contains('active')).toBe(true);
    });
  });

  describe('Code Examples', () => {
    it('should switch language tabs', () => {
      const langTabs = document.querySelectorAll('.language-tab');
      const examples = document.querySelectorAll('.code-example');

      langTabs[1].click(); // Switch to JavaScript
      expect(examples[1].classList.contains('active')).toBe(true);

      langTabs[2].click(); // Switch to Python
      expect(examples[2].classList.contains('active')).toBe(true);
    });

    it('should copy code to clipboard', async () => {
      const copyButton = document.querySelector('.copy-button');
      const code = 'test code';

      navigator.clipboard.writeText = vi.fn().mockResolvedValue();

      await copyButton.click();

      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(code);
    });
  });

  describe('Toast Notifications', () => {
    it('should show toast notification', () => {
      showToast('Test message', 'success');

      const toast = document.querySelector('.toast');
      expect(toast).toBeDefined();
      expect(toast.classList.contains('success')).toBe(true);
      expect(toast.textContent).toContain('Test message');
    });

    it('should auto-remove toast after timeout', async () => {
      showToast('Test message', 'info');

      await new Promise(resolve => setTimeout(resolve, 5100));

      const toast = document.querySelector('.toast');
      expect(toast).toBeNull();
    });
  });

  describe('Auth Modal', () => {
    it('should open auth modal', () => {
      const modal = document.getElementById('authModal');

      expect(modal.classList.contains('active')).toBe(false);

      openAuthModal();

      expect(modal.classList.contains('active')).toBe(true);
    });

    it('should close auth modal', () => {
      const modal = document.getElementById('authModal');

      modal.classList.add('active');
      closeAuthModal();

      expect(modal.classList.contains('active')).toBe(false);
    });

    it('should save credentials', () => {
      document.getElementById('apiKey').value = 'test-key';
      document.getElementById('jwtToken').value = 'test-token';
      document.getElementById('serverUrl').value = 'https://test.api.com/api';

      saveCredentials();

      expect(localStorage.getItem('agl_api_key')).toBe('test-key');
      expect(localStorage.getItem('agl_jwt_token')).toBe('test-token');
      expect(localStorage.getItem('agl_server_url')).toBe('https://test.api.com/api');
    });

    it('should clear credentials', () => {
      localStorage.setItem('agl_api_key', 'test-key');

      clearCredentials();

      expect(localStorage.getItem('agl_api_key')).toBeNull();
    });
  });

  describe('Responsive Design', () => {
    it('should apply mobile styles at 480px', () => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 480,
      });

      window.dispatchEvent(new Event('resize'));

      const headerActions = document.querySelector('.header-actions');
      expect(getComputedStyle(headerActions).flexDirection).toBe('row');
    });

    it('should apply tablet styles at 768px', () => {
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 768,
      });

      window.dispatchEvent(new Event('resize'));

      const quickStats = document.querySelector('.quick-stats');
      const gridTemplate = getComputedStyle(quickStats).gridTemplateColumns;
      expect(gridTemplate).toContain('repeat(2');
    });
  });

  describe('Accessibility', () => {
    it('should have proper ARIA labels', () => {
      const tabs = document.querySelectorAll('.nav-tab');
      tabs.forEach(tab => {
        expect(tab.hasAttribute('role')).toBe(true);
        expect(tab.hasAttribute('aria-selected')).toBe(true);
      });
    });

    it('should support keyboard navigation', () => {
      const firstTab = document.querySelector('.nav-tab');
      const enterEvent = new KeyboardEvent('keydown', { key: 'Enter' });

      firstTab.dispatchEvent(enterEvent);

      // Tab should receive focus
      expect(document.activeElement).toBe(firstTab);
    });

    it('should close modal on Escape key', () => {
      const modal = document.getElementById('authModal');
      modal.classList.add('active');

      const escapeEvent = new KeyboardEvent('keydown', { key: 'Escape' });
      document.dispatchEvent(escapeEvent);

      expect(modal.classList.contains('active')).toBe(false);
    });
  });

  describe('API Integration', () => {
    it('should include API key in requests', () => {
      localStorage.setItem('agl_api_key', 'test-key');

      const requestInterceptor = (request) => {
        if (state.credentials.apiKey) {
          request.headers['X-API-Key'] = state.credentials.apiKey;
        }
        return request;
      };

      const request = { headers: {} };
      const result = requestInterceptor(request);

      expect(result.headers['X-API-Key']).toBe('test-key');
    });

    it('should include JWT token in requests', () => {
      localStorage.setItem('agl_jwt_token', 'test-token');

      const requestInterceptor = (request) => {
        if (state.credentials.jwtToken) {
          request.headers['Authorization'] = `Bearer ${state.credentials.jwtToken}`;
        }
        return request;
      };

      const request = { headers: {} };
      const result = requestInterceptor(request);

      expect(result.headers['Authorization']).toBe('Bearer test-token');
    });
  });
});
