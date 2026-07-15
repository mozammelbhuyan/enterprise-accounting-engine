-- =============================================
-- Procedure: FA_YearEnd
-- Purpose:   Fiscal year-end close. Rolls forward Asset/Liability
--            balances into the new fiscal year as opening balances,
--            and nets all Income/Expenditure accounts into a single
--            Retained Earnings (P&L) account, per business unit.
-- =============================================
ALTER PROCEDURE [dbo].[FA_YearEnd]
    @zid  INT,
    @user VARCHAR(25),
    @year INT,
    @date DATE
AS
BEGIN
    DECLARE
        @row     INT,
        @newyear INT,
        @accpl   INT,
        @voucher INT,
        @buid    INT,
        @acc     INT,
        @sub     INT,
        @plamt   DECIMAL(20,2),
        @prime   DECIMAL(20,2);

    SET @row     = 0;
    SET @newyear = @year + 1;

    -- Retained earnings / P&L account configured per business
    SELECT @accpl = xaccpl FROM acdef WHERE zid = @zid;

    -- Net Income/Expenditure for the closing year (used later to post the P&L transfer)
    SELECT @plamt = ISNULL(SUM(acbal.xprime), 0)
    FROM acmst JOIN acbal ON acmst.zid = acbal.zid AND acmst.xacc = acbal.xacc
    WHERE acmst.zid = @zid AND acbal.xyear = @year
      AND acmst.xacctype IN ('Income', 'Expenditure');

    EXEC Fn_GetTrn @zid, 'FA15', @trn_code = @voucher OUTPUT;

    -- Clear any existing opening balances for the new year (idempotent re-run)
    DELETE FROM acbal WHERE zid = @zid AND xyear = @newyear AND xper = 0;

    -- Roll forward Asset/Liability balances as opening balances of the new year
    DECLARE result_cursor CURSOR FORWARD_ONLY FOR
        SELECT b.xbuid, b.xacc, b.xsub, SUM(ISNULL(b.xprime, 0))
        FROM acmst a JOIN acbal b ON a.zid = b.zid AND a.xacc = b.xacc
        WHERE a.zid = @zid AND xyear = @year AND a.xacctype IN ('Asset', 'Liability')
        GROUP BY b.xbuid, b.xacc, b.xsub;

    OPEN result_cursor;
    FETCH FROM result_cursor INTO @buid, @acc, @sub, @prime;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @row = @row + 1;

        INSERT INTO acbal (ztime, zuserid, zid, xvoucher, xrow,
                            xbuid, xacc, xsub, xprime,
                            xdate, xyear, xper, xref, xhnote, xdnote)
        VALUES (GETDATE(), @user, @zid, @voucher, @row,
                @buid, @acc, @sub, @prime,
                @date, @newyear, 0, '', '', '');

        FETCH NEXT FROM result_cursor INTO @buid, @acc, @sub, @prime;
    END

    CLOSE result_cursor;
    DEALLOCATE result_cursor;

    -- Net Income/Expenditure per business unit into the Retained Earnings account
    IF @plamt != 0
    BEGIN
        DECLARE pnl_cursor CURSOR FORWARD_ONLY FOR
            SELECT b.xbuid, SUM(ISNULL(b.xprime, 0))
            FROM acmst a JOIN acbal b ON a.zid = b.zid AND a.xacc = b.xacc
            WHERE a.zid = @zid AND b.xyear = @year AND a.xacctype IN ('Income', 'Expenditure')
            GROUP BY b.xbuid;

        OPEN pnl_cursor;
        FETCH FROM pnl_cursor INTO @buid, @prime;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @prime <> 0
            BEGIN
                SET @row = @row + 1;

                INSERT INTO acbal (ztime, zuserid, zid, xvoucher, xrow,
                                    xbuid, xacc, xsub, xprime,
                                    xdate, xyear, xper, xref, xhnote, xdnote)
                VALUES (GETDATE(), @user, @zid, @voucher, @row,
                        @buid, @accpl, NULL, @prime,
                        @date, @newyear, 0, '', '', '');
            END

            FETCH NEXT FROM pnl_cursor INTO @buid, @prime;
        END

        CLOSE pnl_cursor;
        DEALLOCATE pnl_cursor;
    END

    -- Record the closed fiscal year on the business's accounting defaults
    UPDATE acdef SET xclyear = @year, xcldate = GETDATE() WHERE zid = @zid;
END
