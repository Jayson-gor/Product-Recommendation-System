CREATE OR REPLACE VIEW widget_context_item_similar AS
WITH Underperforming_Products AS (
    SELECT *
    FROM product-recommendation-421809.product_data.widget_context_item_target_kpis
    WHERE widget = 'similar'
        AND kpis.mainImpressions > 50
        AND kpis.click_n_buys < 5
        AND kpis.CTR <= 0.06
        AND kpis.click_n_buys / kpis.mainImpressions < 0.001
),

SimilarCategoryViewData AS (
    SELECT
        source_pps.product_id AS source_product_id,
        target_pps.product_id AS target_product_id,
        COUNT(DISTINCT os.session_id) AS same_sessions
    FROM product-recommendation-421809.product_data.product_views AS os
    JOIN product-recommendation-421809.product_data.product_views AS ot ON os.session_id = ot.session_id AND os.group_id != ot.group_id
    LEFT JOIN product-recommendation-421809.product_data.product_property_structures AS source_pps ON os.group_id = source_pps.product_id
    LEFT JOIN product-recommendation-421809.product_data.product_property_structures AS target_pps ON ot.group_id = target_pps.product_id
    WHERE source_pps.product_id_properties.categories_de_3[SAFE_OFFSET(0)] = target_pps.product_id_properties.categories_de_3[SAFE_OFFSET(0)]
    GROUP BY source_product_id, target_product_id
    HAVING COUNT(DISTINCT os.session_id) > 1
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
        COUNTIF(fud.target_product.product_id IS NOT NULL) AS remove_count
    FROM product-recommendation-421809.product_data.widget_context_item_source_target_kpis sti
    LEFT JOIN Underperforming_Products fud ON sti.target_product.product_id = fud.target_product.product_id
    WHERE sti.widget = 'similar'
    GROUP BY sti.source_product.product_id
),

AggregatedRecommendations AS (
    SELECT
        sd.source_product.product_id AS source_product_id,
        tp.target_product,
        tp.kpis,
        'MAIN' AS recommendation_type,
        scvd.same_sessions
    FROM CurrentRecos sd
    JOIN product-recommendation-421809.product_data.widget_context_item_target_kpis tp ON sd.source_product.gender = tp.target_product.gender 
        AND sd.source_product.category = tp.target_product.category
        AND NOT tp.target_product.product_id IN UNNEST(sd.target_product_ids)
    LEFT JOIN SimilarCategoryViewData scvd ON tp.target_product.product_id = scvd.target_product_id
    LEFT JOIN Underperforming_Products nfp ON tp.target_product.product_id = nfp.target_product.product_id
    LEFT JOIN product-recommendation-421809.product_data.widget_context_item_eligible_products epg ON tp.target_product.products_group_id = epg.products_group_id
    WHERE sd.remove_count > 0
      AND nfp.target_product.product_id IS NULL
      AND tp.widget = 'similar'
      AND tp.kpis.mainImpressions > 1
      AND tp.kpis.CTR > 0.07
      AND tp.kpis.click_n_buys >= 1
      AND epg.products_group_id IS NOT NULL
    UNION ALL
    SELECT
        sd.source_product.product_id AS source_product_id,
        srp.target_product,
        srp.kpis,
        'FALLBACK' AS recommendation_type,
        scvd.same_sessions
    FROM CurrentRecos sd
    JOIN product-recommendation-421809.product_data.widget_context_item_target_kpis srp ON sd.source_product.gender = srp.target_product.gender 
        AND sd.source_product.category = srp.target_product.category
        AND NOT srp.target_product.product_id IN UNNEST(sd.target_product_ids)
    LEFT JOIN SimilarCategoryViewData scvd ON srp.target_product.product_id = scvd.target_product_id
    LEFT JOIN product-recommendation-421809.product_data.widget_context_item_eligible_products epg ON srp.target_product.products_group_id = epg.products_group_id
    WHERE sd.remove_count > 0
      AND scvd.same_sessions > 5
      AND srp.widget = 'similar'
      AND srp.kpis.CTR > 0.1
      AND srp.kpis.mainImpressions BETWEEN 1 AND 50
      AND scvd.same_sessions > 5
      AND epg.products_group_id IS NOT NULL
),

PotentialRecos AS (
    SELECT
        source_product_id,
        target_product,
        kpis,
        recommendation_type,
        same_sessions
    FROM AggregatedRecommendations
    ORDER BY kpis.click_n_buys DESC, kpis.CTR DESC, same_sessions DESC
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
    'similar' AS widget,
    cr.target_info AS current_recommendations,
    nr.new_recommendations
FROM CurrentRecos cr
LEFT JOIN NewRecos nr ON cr.source_product.product_id = nr.source_product_id;
