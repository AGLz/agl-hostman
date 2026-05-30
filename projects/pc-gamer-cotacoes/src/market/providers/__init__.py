from src.market.providers.aliexpress import AliExpressProvider
from src.market.providers.fourgamers import FourGamersProvider
from src.market.providers.mercadolivre import MercadoLivreProvider

PROVIDERS = {
    "mercadolivre": MercadoLivreProvider(),
    "aliexpress": AliExpressProvider(),
    "4gamers": FourGamersProvider(),
}
