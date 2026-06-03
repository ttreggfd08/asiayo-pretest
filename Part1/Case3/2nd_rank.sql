-- ------------------------------------------------------------
--   成績先由高到低排序，再 JOIN 班級表，取出排名第 2 名。
--   DENSE_RANK 的好處：若有兩人並列第一同分，下一名仍會是第二名。
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT
        s.name,
        s.score,
        DENSE_RANK() OVER (ORDER BY s.score DESC) AS rnk
    FROM score AS s
)
SELECT
    c.name,
    r.score,
    c.class
FROM ranked AS r
JOIN class AS c ON c.name = r.name
WHERE r.rnk = 2;
