-- =============================================
-- Procedure: FA_VoucherPost
-- Purpose:   Posts a balanced journal voucher into the GL balance table
--            (acbal). Only vouchers whose header status is 'Balanced'
--            (i.e. total debits = total credits) and that have at
--            least one detail line are eligible for posting.
-- =============================================
ALTER PROCEDURE [dbo].[FA_VoucherPost]
    @zid     INT,
    @user    VARCHAR(25),
    @voucher INT
AS
BEGIN
    DECLARE
        @count  INT,
        @count1 INT,
        @date   DATE,
        @buid   INT,
        @hnote  VARCHAR(200),
        @dnote  VARCHAR(200),
        @year   INT,
        @per    INT,
        @ref    VARCHAR(100);

    -- Check if the voucher can be posted
    SELECT @count = COUNT(*) FROM acheader
    WHERE zid = @zid AND xvoucher = @voucher AND xstatusjv = 'Balanced';

    SELECT @count1 = COUNT(*) FROM acdetail
    WHERE zid = @zid AND xvoucher = @voucher;

    IF @count = 1 AND @count1 > 0
    BEGIN
        -- Get header information
        SELECT @date = xdate, @buid = xbuid, @hnote = xnote,
               @year = xyear, @per = xper, @ref = xref
        FROM acheader WHERE zid = @zid AND xvoucher = @voucher;

        -- Push all detail lines into the GL balance table in one set-based insert
        INSERT INTO acbal (
            ztime, zuserid, zid, xvoucher, xrow,
            xacc, xsub, xprime, xbuid, xdate,
            xyear, xper, xref, xhnote, xdnote
        )
        SELECT
            GETDATE(), @user, @zid, @voucher, xrow,
            xacc, xsub, xprime, @buid, @date,
            @year, @per, @ref, @hnote, xnote
        FROM acdetail WHERE zid = @zid AND xvoucher = @voucher;

        -- Flip voucher status to Posted
        UPDATE acheader SET xstatusjv = 'Posted', zutime = GETDATE(), zuuserid = @user
        WHERE zid = @zid AND xvoucher = @voucher;
    END
END;
