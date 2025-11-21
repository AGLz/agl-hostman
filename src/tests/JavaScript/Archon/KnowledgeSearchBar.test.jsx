import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import KnowledgeSearchBar from '@/Components/Archon/KnowledgeSearchBar';

describe('KnowledgeSearchBar', () => {
    const mockOnSearch = vi.fn();
    const mockSuggestions = ['WireGuard mesh', 'Docker setup', 'React hooks'];

    beforeEach(() => {
        mockOnSearch.mockClear();
    });

    it('renders search input with placeholder', () => {
        render(<KnowledgeSearchBar query="" onSearch={mockOnSearch} />);

        const input = screen.getByPlaceholderText(/Search knowledge base/i);
        expect(input).toBeInTheDocument();
    });

    it('calls onSearch when form is submitted', () => {
        render(<KnowledgeSearchBar query="" onSearch={mockOnSearch} />);

        const input = screen.getByPlaceholderText(/Search knowledge base/i);
        const form = input.closest('form');

        fireEvent.change(input, { target: { value: 'test query' } });
        fireEvent.submit(form);

        expect(mockOnSearch).toHaveBeenCalledWith('test query');
    });

    it('displays suggestions when provided', () => {
        render(
            <KnowledgeSearchBar
                query="wire"
                onSearch={mockOnSearch}
                suggestions={mockSuggestions}
            />
        );

        mockSuggestions.forEach(suggestion => {
            expect(screen.getByText(suggestion)).toBeInTheDocument();
        });
    });

    it('handles keyboard navigation through suggestions', async () => {
        render(
            <KnowledgeSearchBar
                query="wire"
                onSearch={mockOnSearch}
                suggestions={mockSuggestions}
            />
        );

        const input = screen.getByPlaceholderText(/Search knowledge base/i);

        // Press Arrow Down
        fireEvent.keyDown(input, { key: 'ArrowDown' });

        await waitFor(() => {
            const firstSuggestion = screen.getByText(mockSuggestions[0]);
            expect(firstSuggestion.closest('button')).toHaveClass('bg-blue-50');
        });
    });

    it('selects suggestion on click', () => {
        render(
            <KnowledgeSearchBar
                query="wire"
                onSearch={mockOnSearch}
                suggestions={mockSuggestions}
            />
        );

        const firstSuggestion = screen.getByText(mockSuggestions[0]);
        fireEvent.click(firstSuggestion);

        expect(mockOnSearch).toHaveBeenCalledWith(mockSuggestions[0]);
    });

    it('disables search button when query is empty', () => {
        render(<KnowledgeSearchBar query="" onSearch={mockOnSearch} />);

        const searchButton = screen.getByRole('button', { name: /search/i });
        expect(searchButton).toBeDisabled();
    });

    it('shows loading state', () => {
        render(
            <KnowledgeSearchBar
                query="test"
                onSearch={mockOnSearch}
                isLoading={true}
            />
        );

        const searchButton = screen.getByRole('button');
        expect(searchButton).toBeDisabled();
        expect(searchButton.textContent).toContain('⏳');
    });

    it('updates local query state on input change', () => {
        const { rerender } = render(
            <KnowledgeSearchBar query="" onSearch={mockOnSearch} />
        );

        const input = screen.getByPlaceholderText(/Search knowledge base/i);
        fireEvent.change(input, { target: { value: 'new query' } });

        expect(input.value).toBe('new query');
    });

    it('hides suggestions on Escape key', async () => {
        render(
            <KnowledgeSearchBar
                query="wire"
                onSearch={mockOnSearch}
                suggestions={mockSuggestions}
            />
        );

        const input = screen.getByPlaceholderText(/Search knowledge base/i);
        fireEvent.keyDown(input, { key: 'Escape' });

        await waitFor(() => {
            expect(screen.queryByText(mockSuggestions[0])).not.toBeInTheDocument();
        });
    });
});
