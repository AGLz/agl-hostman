/** Formata centavos BRL para exibição (pt-BR). */
export function formatCents(cents) {
    if (cents === null || cents === undefined || cents === "") {
        return "—";
    }
    return new Intl.NumberFormat("pt-BR", {
        style: "currency",
        currency: "BRL",
    }).format(Number(cents) / 100);
}

export const BUILD_STATUS_LABELS = {
    draft: "Rascunho",
    quoted: "Cotado",
    approved: "Aprovado",
    ordered: "Encomendado",
    assembly: "Montagem",
    completed: "Concluído",
    cancelled: "Cancelado",
};

/** Próximos estados permitidos na UI (fluxo principal + cancelar). */
export const BUILD_STATUS_TRANSITIONS = {
    draft: ["quoted", "cancelled"],
    quoted: ["approved", "draft", "cancelled"],
    approved: ["ordered", "cancelled"],
    ordered: ["assembly", "cancelled"],
    assembly: ["completed", "cancelled"],
    completed: [],
    cancelled: ["draft"],
};

/** Rotas web PC Gamer (sem Ziggy). */
export const pcgRoutes = {
    buildsIndex: "/pc-gamer/builds",
    buildsShow: (id) => `/pc-gamer/builds/${id}`,
    buildsStore: "/pc-gamer/builds",
    buildsItemUpdate: (buildId, itemId) =>
        `/pc-gamer/builds/${buildId}/items/${itemId}`,
    buildsTransition: (buildId) => `/pc-gamer/builds/${buildId}/transition`,
    marketPrices: "/pc-gamer/market-prices",
    presets: "/pc-gamer/presets",
    catalog: "/pc-gamer/catalog",
    catalogStore: "/pc-gamer/catalog/components",
};
