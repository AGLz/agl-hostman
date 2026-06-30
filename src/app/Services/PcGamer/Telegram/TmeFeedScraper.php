<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Telegram;

use App\DTO\PcGamer\TmePost;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class TmeFeedScraper
{
    private const MESSAGE_BLOCK = '/data-post="(?P<post>[^"]+)"[^>]*>.*?class="tgme_widget_message_text[^"]*"[^>]*>(?P<body>.*?)<\/div>/s';

    public function usernameFromChatKey(string $chatKey): ?string
    {
        $key = trim($chatKey);
        if (str_starts_with($key, '@')) {
            return substr($key, 1);
        }
        if (preg_match('/(?:t\.me\/|telegram\.me\/)([A-Za-z0-9_]{4,32})/', $key, $m)) {
            return $m[1];
        }

        return null;
    }

    /**
     * @return list<TmePost>
     */
    public function parseFeedHtml(string $chatKey, string $htmlPage, int $limit = 20): array
    {
        $username = $this->usernameFromChatKey($chatKey) ?? ltrim($chatKey, '@');
        $posts = [];

        if (! preg_match_all(self::MESSAGE_BLOCK, $htmlPage, $matches, PREG_SET_ORDER)) {
            return [];
        }

        foreach ($matches as $match) {
            $postPath = $match['post'];
            if (! str_contains($postPath, '/')) {
                continue;
            }
            $msgIdRaw = substr($postPath, strrpos($postPath, '/') + 1);
            if (! ctype_digit($msgIdRaw)) {
                continue;
            }
            $messageId = (int) $msgIdRaw;
            $text = $this->htmlToText($match['body']);
            if (strlen($text) < 12) {
                continue;
            }
            $posts[] = new TmePost(
                chatKey: '@' . $username,
                messageId: $messageId,
                text: $text,
                postUrl: 'https://t.me/' . $postPath,
            );
            if (count($posts) >= $limit) {
                break;
            }
        }

        return $posts;
    }

    /**
     * @return list<TmePost>
     */
    public function fetchChannelPosts(string $chatKey, int $limit = 20): array
    {
        $username = $this->usernameFromChatKey($chatKey);
        if ($username === null) {
            throw new \InvalidArgumentException("Chat key inválido para t.me/s/: {$chatKey}");
        }

        $url = "https://t.me/s/{$username}";
        $response = Http::timeout(30)
            ->withHeaders(['User-Agent' => 'Mozilla/5.0 (compatible; AGLPcGamer/1.0)'])
            ->get($url);

        $response->throw();
        $htmlPage = $response->body();

        if (! str_contains($htmlPage, 'tgme_widget_message')) {
            throw new RuntimeException("Feed vazio ou bloqueado para {$chatKey} ({$url})");
        }

        return $this->parseFeedHtml($chatKey, $htmlPage, $limit);
    }

    private function htmlToText(string $raw): string
    {
        $text = preg_replace('/<br\s*\/?>/i', "\n", $raw) ?? $raw;
        $text = preg_replace('/<[^>]+>/', '', $text) ?? $text;

        return trim(html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
    }
}
