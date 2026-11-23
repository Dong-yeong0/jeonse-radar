-- 건물 전세가율 중앙값은 0~300% 안이어야 한다
SELECT building_key, median_jeonse_rate
FROM {{ ref('mart_building_risk') }}
WHERE median_jeonse_rate < 0 OR median_jeonse_rate > 3
