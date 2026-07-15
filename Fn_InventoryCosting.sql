-- =============================================
-- Procedure: Fn_InventoryCosting  (excerpt)
-- Purpose:   Computes the cost of an inventory issue transaction by
--            consuming open receipt lots (imtrn, xsign = 1) in the
--            order appropriate to the business's configured costing
--            method, then writes the computed rate/value back onto
--            the issue transaction (xsign = -1).
--
--            Supports three methods, selected per business via @isstype:
--              FIFO             - consumes oldest open receipt lots first
--              LIFO             - consumes newest open receipt lots first
--              Weighted Average - blends the rate across all open lots
--
--            Partially-consumed lots are tracked via a running "used
--            quantity" column (xcqtyuse) so each lot can be drawn down
--            across multiple issue transactions without double-counting.
-- =============================================
ALTER PROCEDURE [dbo].[Fn_InventoryCosting]
    @zid     INT,
    @trnnum  INT,     -- imtrn record of the issue being costed
    @isstype VARCHAR(20)
AS
BEGIN
    DECLARE
        @item     INT,
        @imtrnnum INT,
        @qty      DECIMAL(19,2),
        @wh       INT,
        @reqty    DECIMAL(19,2),
        @totqty   DECIMAL(19,2),
        @cqtyuse  DECIMAL(19,2),
        @rate     DECIMAL(19,4),
        @totval   DECIMAL(19,4),
        @tempbal  DECIMAL(19,4),
        @buid     INT;

    SET @qty = 0; SET @reqty = 0; SET @totqty = 0;
    SET @cqtyuse = 0; SET @rate = 0; SET @totval = 0; SET @tempbal = 0;

    -- Only proceed if this is a valid, un-costed issue transaction
    IF EXISTS (SELECT ximtrnnum FROM imtrn WHERE zid = @zid AND ximtrnnum = @trnnum AND xsign = -1 AND xqty > 0)
    BEGIN
        SELECT @buid = xbuid, @wh = xwh, @item = xitem, @reqty = xqty
        FROM imtrn WHERE zid = @zid AND ximtrnnum = @trnnum;

        -- ===================== FIFO =====================
        IF @isstype = 'FIFO'
        BEGIN
            SET @tempbal = @reqty;

            DECLARE item_cursor_fifo CURSOR FORWARD_ONLY FOR
                SELECT ximtrnnum, xqty, ISNULL(xcqtyuse, 0),
                       CASE WHEN ISNULL(xrateavg, 0) = 0 THEN ISNULL(xrate, 0) ELSE xrateavg END
                FROM imtrn
                WHERE zid = @zid AND xbuid = @buid AND xwh = @wh AND xitem = @item AND xsign = 1
                  AND (xqty - ISNULL(xcqtyuse, 0)) > 0
                ORDER BY xdate ASC; -- oldest lots first

            OPEN item_cursor_fifo;
            FETCH FROM item_cursor_fifo INTO @imtrnnum, @qty, @cqtyuse, @rate;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @tempbal > 0
                BEGIN
                    IF @tempbal - (@qty - @cqtyuse) >= 0
                    BEGIN
                        -- This lot is fully consumed by the remaining issue quantity
                        UPDATE imtrn SET xcqtyuse = @qty WHERE zid = @zid AND ximtrnnum = @imtrnnum;
                        SET @totval  = @totval + @rate * (@qty - @cqtyuse);
                        SET @tempbal = @tempbal - (@qty - @cqtyuse);
                    END
                    ELSE
                    BEGIN
                        -- This lot only partially covers the remaining issue quantity
                        UPDATE imtrn SET xcqtyuse = @tempbal + @cqtyuse WHERE zid = @zid AND ximtrnnum = @imtrnnum;
                        SET @totval  = @totval + @rate * @tempbal;
                        SET @tempbal = 0;
                    END
                END

                FETCH NEXT FROM item_cursor_fifo INTO @imtrnnum, @qty, @cqtyuse, @rate;
            END

            CLOSE item_cursor_fifo;
            DEALLOCATE item_cursor_fifo;

            UPDATE imtrn SET xrate = @totval / @reqty, xval = @totval
            WHERE zid = @zid AND ximtrnnum = @trnnum;
        END

        -- ===================== LIFO =====================
        ELSE IF @isstype = 'LIFO'
        BEGIN
            SET @tempbal = @reqty;

            DECLARE item_cursor_lifo CURSOR FORWARD_ONLY FOR
                SELECT ximtrnnum, xqty, ISNULL(xcqtyuse, 0),
                       CASE WHEN ISNULL(xrateavg, 0) = 0 THEN ISNULL(xrate, 0) ELSE xrateavg END
                FROM imtrn
                WHERE zid = @zid AND xbuid = @buid AND xwh = @wh AND xitem = @item AND xsign = 1
                  AND (xqty - ISNULL(xcqtyuse, 0)) > 0
                ORDER BY xdate DESC; -- newest lots first

            OPEN item_cursor_lifo;
            FETCH FROM item_cursor_lifo INTO @imtrnnum, @qty, @cqtyuse, @rate;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @tempbal > 0
                BEGIN
                    IF @tempbal - (@qty - @cqtyuse) >= 0
                    BEGIN
                        UPDATE imtrn SET xcqtyuse = @qty WHERE zid = @zid AND ximtrnnum = @imtrnnum;
                        SET @totval  = @totval + @rate * (@qty - @cqtyuse);
                        SET @tempbal = @tempbal - (@qty - @cqtyuse);
                    END
                    ELSE
                    BEGIN
                        UPDATE imtrn SET xcqtyuse = @tempbal + @cqtyuse WHERE zid = @zid AND ximtrnnum = @imtrnnum;
                        SET @totval  = @totval + @rate * @tempbal;
                        SET @tempbal = 0;
                    END
                END

                FETCH NEXT FROM item_cursor_lifo INTO @imtrnnum, @qty, @cqtyuse, @rate;
            END

            CLOSE item_cursor_lifo;
            DEALLOCATE item_cursor_lifo;

            UPDATE imtrn SET xrate = @totval / @reqty, xval = @totval
            WHERE zid = @zid AND ximtrnnum = @trnnum;
        END

        -- ================ Weighted Average ================
        ELSE IF @isstype = 'Weighted Average'
        BEGIN
            -- Blend the rate across all currently open lots for this item/warehouse
            SELECT
                @totqty = SUM((xqty - ISNULL(xcqtyuse, 0))),
                @totval = SUM((xqty - ISNULL(xcqtyuse, 0)) *
                          (CASE WHEN ISNULL(xrateavg, 0) = 0 THEN ISNULL(xrate, 0) ELSE xrateavg END))
            FROM imtrn
            WHERE zid = @zid AND xbuid = @buid AND xwh = @wh AND xitem = @item AND xsign = 1
              AND (xqty - ISNULL(xcqtyuse, 0)) > 0;

            SET @totqty  = ISNULL(@totqty, 0);
            SET @totval  = ISNULL(@totval, 0);
            SET @tempbal = @reqty;

            IF @totqty > 0
                SET @rate = @totval / @totqty;

            -- Stamp the blended rate onto all open lots so future issues reuse it
            UPDATE imtrn SET xrateavg = @rate
            WHERE zid = @zid AND xbuid = @buid AND xwh = @wh AND xitem = @item
              AND xsign = 1 AND (xqty - ISNULL(xcqtyuse, 0)) > 0;

            UPDATE imtrn SET xrate = @rate, xval = xqty * @rate
            WHERE zid = @zid AND ximtrnnum = @trnnum;

            -- Still walk the open lots oldest-first to mark them as consumed
            DECLARE item_cursor_avg CURSOR FORWARD_ONLY FOR
                SELECT ximtrnnum, xqty, ISNULL(xcqtyuse, 0)
                FROM imtrn
                WHERE zid = @zid AND xbuid = @buid AND xwh = @wh AND xitem = @item AND xsign = 1
                  AND (xqty - ISNULL(xcqtyuse, 0)) > 0
                ORDER BY xdate ASC;

            OPEN item_cursor_avg;
            FETCH FROM item_cursor_avg INTO @imtrnnum, @qty, @cqtyuse;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @tempbal > 0
                BEGIN
                    IF @tempbal - (@qty - @cqtyuse) >= 0
                    BEGIN
                        UPDATE imtrn SET xcqtyuse = @qty WHERE zid = @zid AND ximtrnnum = @imtrnnum;
                        SET @tempbal = @tempbal - (@qty - @cqtyuse);
                    END
                    ELSE
                    BEGIN
                        UPDATE imtrn SET xcqtyuse = @tempbal + @cqtyuse WHERE zid = @zid AND ximtrnnum = @imtrnnum;
                        SET @tempbal = 0;
                    END
                END

                FETCH NEXT FROM item_cursor_avg INTO @imtrnnum, @qty, @cqtyuse;
            END

            CLOSE item_cursor_avg;
            DEALLOCATE item_cursor_avg;
        END
    END
END
