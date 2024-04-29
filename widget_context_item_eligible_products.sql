CREATE OR REPLACE VIEW widget_context_item_eligible_products AS
SELECT
    p.products_group_id,
    ANY_VALUE(season.property_value) AS season,
    ANY_VALUE(stock.property_value) AS stock
FROM
    product-recommendation-421809.product_data.product_image_and_title AS p
JOIN
    product-recommendation-421809.product_data.product_string_properties AS season 
    ON
    EXISTS (
        SELECT 1 FROM UNNEST(p.product_ids) AS prod_id
        WHERE prod_id = season.product_id
    )
    AND season.property_name = 'bq_custom_current_season_number'
    AND season.property_value = '1'
JOIN
    product-recommendation-421809.product_data.product_string_properties AS stock 
    ON
    EXISTS (
        SELECT 1 FROM UNNEST(p.product_ids) AS prod_id
        WHERE prod_id = stock.product_id
    )
    AND stock.property_name = 'bq_custom_group_stock'
    AND SAFE_CAST(stock.property_value AS INT64) >= 10
WHERE
    p.is_active = 1
GROUP BY
    p.products_group_id;
