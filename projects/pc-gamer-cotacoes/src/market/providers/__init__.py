from src.market.providers.aliexpress import AliExpressProvider
from src.market.providers.fourgamers import FourGamersProvider
from src.market.providers.mercadolivre import MercadoLivreProvider
from src.market.providers.pichau import PichauProvider

PROVIDERS = {
    "mercadolivre": MercadoLivreProvider(),
    "pichau": PichauProvider(),
    "aliexpress": AliExpressProvider(),
    "4gamers": FourGamersProvider(),
}
