CREATE OR REPLACE VIEW widget_context_item_recos_effect AS
SELECT 
    widget,
    source_product,
    r.target_product,
    FALSE AS positive
FROM 
    product-recommendation-421809.product_data.widget_context_item_recos
JOIN UNNEST(current_recommendations) AS r 
    ON r.affected_status IN ('REPLACE', 'REMOVE') 
    AND r.target_product IS NOT NULL

UNION ALL

SELECT 
    widget,
    source_product,
    r.target_product,
    TRUE AS positive
FROM 
    product-recommendation-421809.product_data.widget_context_item_recos
JOIN UNNEST(new_recommendations) AS r 
    ON r.target_product IS NOT NULL;
