CREATE OR REPLACE VIEW widget_context_item_basket AS
WITH Underperforming_Products AS (
    SELECT
        *
    FROM product-recommendation-421809.product_data.widget_context_item_target_kpis
    WHERE widget = 'basket'
        AND kpis.mainImpressions > 50
        AND kpis.click_n_buys < 4
        AND kpis.CTR <= 0.024390243902439025
        AND kpis.BTR < 0.001
),

BoughtTogether AS (
    SELECT
        source_pps.product_id AS source_product_id,
        target_pps.product_id AS target_product_id,
        COUNT(*) AS bought_together
    FROM product-recommendation-421809.product_data.order_product AS os
    JOIN product-recommendation-421809.product_data.order_product AS ot ON os.order_id = ot.order_id AND os.product_id != ot.product_id
    LEFT JOIN product-recommendation-421809.product_data.product_property_structures AS source_pps ON os.product_id = source_pps.product_id
    LEFT JOIN product-recommendation-421809.product_data.product_property_structures AS target_pps ON ot.product_id = target_pps.product_id
    WHERE source_pps.product_id_properties.categories_de_3[SAFE_OFFSET(0)] != target_pps.product_id_properties.categories_de_3[SAFE_OFFSET(0)]
    GROUP BY source_product_id, target_product_id
),

CurrentRecos AS (
    SELECT
        ANY_VALUE(sti.source_product) AS source_product,
        ARRAY_AGG(sti.target_product.product_id) AS target_product_ids,
        ARRAY_AGG(STRUCT(
          sti.target_product AS target_product,
          sti.kpis AS kpis,
          CASE WHEN fud.target_product.product_id IS NOT NULL THEN 'REMOVE' ELSE 'KEEP' END AS affected_status
        )) AS target_info,
        COUNTIF(fud.target_product.product_id IS NOT NULL) AS replace_count
    FROM product-recommendation-421809.product_data.widget_context_item_source_target_kpis sti
    LEFT JOIN Underperforming_Products fud ON sti.target_product.product_id = fud.target_product.product_id
    WHERE sti.widget = 'basket'
    GROUP BY sti.source_product.product_id
),

AggregatedRecommendations AS (
    SELECT
        sd.source_product.product_id AS source_product_id,
        tp.target_product,
        tp.kpis,
        'MAIN' AS recommendation_type,
        bt.bought_together
    FROM CurrentRecos sd
    JOIN product-recommendation-421809.product_data.widget_context_item_target_kpis tp ON sd.source_product.gender = tp.target_product.gender
        AND sd.source_product.price >= tp.target_product.price
        AND sd.source_product.category != tp.target_product.category
        AND NOT tp.target_product.product_id IN UNNEST(sd.target_product_ids)
    LEFT JOIN BoughtTogether bt ON tp.target_product.product_id = bt.target_product_id
    LEFT JOIN Underperforming_Products nfp ON tp.target_product.product_id = nfp.target_product.product_id
    JOIN product-recommendation-421809.product_data.widget_context_item_eligible_products epg ON tp.target_product.products_group_id = epg.products_group_id
    WHERE sd.replace_count > 0 
        AND tp.widget = 'basket'
        AND tp.kpis.mainImpressions > 50
        AND tp.kpis.CTR > 0.020
        AND nfp.target_product.product_id IS NULL
    UNION ALL
    SELECT
        sd.source_product.product_id AS source_product_id,
        tk.target_product,
        tk.kpis,
        'FALLBACK' AS recommendation_type,
        bt.bought_together
    FROM CurrentRecos sd
    JOIN product-recommendation-421809.product_data.widget_context_item_target_kpis tk ON sd.source_product.gender = tk.target_product.gender
        AND sd.source_product.price >= tk.target_product.price
        AND sd.source_product.category != tk.target_product.category
        AND NOT tk.target_product.product_id IN UNNEST(sd.target_product_ids)
    LEFT JOIN BoughtTogether bt ON tk.target_product.product_id = bt.target_product_id
    JOIN product-recommendation-421809.product_data.widget_context_item_eligible_products epg ON tk.target_product.products_group_id = epg.products_group_id
    WHERE sd.replace_count > 0
        AND tk.widget = 'basket'
        AND tk.kpis.CTR > 0.020
        AND tk.kpis.mainImpressions BETWEEN 1 AND 50
),

PotentialRecos AS (
    SELECT
        source_product_id,
        target_product,
        kpis,
        recommendation_type,
        bought_together
    FROM AggregatedRecommendations
    ORDER BY kpis.click_n_buys DESC, bought_together DESC, kpis.CTR DESC
),

NewRecos AS (
    SELECT
        pr.source_product_id,
        ARRAY_AGG(STRUCT(
            pr.target_product,
            pr.kpis,
            pr.recommendation_type
        ) ORDER BY RAND() LIMIT 4) AS new_recommendations
    FROM PotentialRecos pr
    GROUP BY pr.source_product_id
)

SELECT
    cr.source_product,
    'basket' AS widget,
    cr.target_info AS current_recommendations,
    nr.new_recommendations
FROM CurrentRecos cr
LEFT JOIN NewRecos nr ON cr.source_product.product_id = nr.source_product_id;
