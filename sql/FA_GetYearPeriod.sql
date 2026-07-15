-- =============================================
-- Procedure: FA_GetYearPeriod
-- Purpose:   Resolves the fiscal year and period (month) for a given
--            transaction date, supporting businesses whose fiscal year
--            does not start in January (offset stored per-business).
-- =============================================
ALTER PROCEDURE [dbo].[FA_GetYearPeriod]
    @zid  INT,
    @date DATE,
    @year INT OUTPUT,
    @per  INT OUTPUT
AS
BEGIN
    DECLARE @offset INT;

    SET @year = YEAR(@date);
    SET @per  = MONTH(@date);

    -- Per-business fiscal year start offset (e.g. 0 = Jan, 6 = July)
    SELECT @offset = xoffset FROM acdef WHERE zid = @zid;

    SET @per = 12 + @per - @offset;

    IF @per <= 12
        SET @year = @year - 1;
    ELSE
        SET @per = @per - 12;

    RETURN;
END
