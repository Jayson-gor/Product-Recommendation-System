CREATE OR REPLACE TABLE widget_context_item_recos AS
SELECT * 
FROM product-recommendation-421809.product_data.widget_context_item_basket

UNION ALL

SELECT * 
FROM product-recommendation-421809.product_data.widget_context_item_similar;
