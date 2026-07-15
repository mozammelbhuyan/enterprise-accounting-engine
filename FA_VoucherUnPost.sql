-- =============================================
-- Procedure: FA_VoucherUnPost
-- Purpose:   Reverses a posted voucher — removes its GL balance rows
--            and reverts header status back to 'Balanced' so it can
--            be edited or re-posted. Fully transactional: any failure
--            rolls back both operations together.
-- =============================================
ALTER PROCEDURE [dbo].[FA_VoucherUnPost]
    @zid     INT,
    @user    VARCHAR(25),
    @voucher INT
AS
BEGIN
    SET NOCOUNT ON; -- Prevents extra result sets from interfering with SELECT statements.

    BEGIN TRY
        BEGIN TRANSACTION; -- Ensure atomicity for the operations.

        -- Remove GL balance rows
        DELETE FROM acbal WHERE zid = @zid AND xvoucher = @voucher;

        -- Revert voucher status
        UPDATE acheader SET xstatusjv = 'Balanced', zutime = GETDATE(), zuuserid = @user
        WHERE zid = @zid AND xvoucher = @voucher;

        COMMIT TRANSACTION; -- Commit the transaction if both operations succeed.
    END TRY
    BEGIN CATCH
        -- Rollback the transaction in case of any error.
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Optionally, log the error or re-throw it.
        THROW;
    END CATCH;
END;
