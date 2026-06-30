"""Testes do parser HTML t.me/s/ (sem rede)."""

from __future__ import annotations

from src.telegram.scraper_tme import parse_feed_html


SAMPLE_HTML = """
<div class="tgme_widget_message_wrap">
  <div class="tgme_widget_message" data-post="mmpromo/12345">
    <div class="tgme_widget_message_text js-message_text" dir="auto">
      Placa RTX 4060 8GB<br/>
      &#036; R&#036; 1.899,90<br/>
      https://kabum.com.br/produto/123
    </div>
  </div>
</div>
"""


def test_parse_feed_html_extrai_mensagem_e_decodifica_entidades() -> None:
    posts = parse_feed_html("@mmpromo", SAMPLE_HTML, limit=5)
    assert len(posts) == 1
    post = posts[0]
    assert post.message_id == 12345
    assert post.chat_key == "@mmpromo"
    assert "R$ 1.899,90" in post.text
    assert "kabum.com.br" in post.text
