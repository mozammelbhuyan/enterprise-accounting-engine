-- =============================================
-- Procedure: Fn_GetTrn
-- Purpose:   Generates the next sequential transaction number for a
--            given business + screen, guaranteeing uniqueness under
--            concurrent access via an atomic UPDATE...OUTPUT pattern
--            instead of a separate SELECT-then-UPDATE (which would be
--            vulnerable to a race condition).
-- =============================================
ALTER PROCEDURE [dbo].[Fn_GetTrn]
    @zid      INT,
    @screen   VARCHAR(10),
    @trn_code INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; -- Prevents extra result sets from interfering with SELECT statements.

    BEGIN TRY
        BEGIN TRANSACTION; -- Ensure atomicity for the operation.

        -- Fetch and increment the transaction number in a single atomic statement
        -- to avoid two concurrent callers reading the same "next" number.
        UPDATE xscreens
        SET @trn_code = xnum + 1,
            xnum = xnum + 1
        WHERE zid = @zid AND xscreen = @screen;

        -- First transaction ever requested for this business + screen: seed the counter.
        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO xscreens (zid, xscreen, xnum)
            VALUES (@zid, @screen, 1);

            SET @trn_code = 1;
        END

        COMMIT TRANSACTION; -- Commit the transaction if successful.
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END
