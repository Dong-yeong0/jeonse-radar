# API response fields (verified 2026-11-22)

Sample calls made with the development key. Raw responses are saved in `tests/fixtures/`.

## RTMS row-house rent (`RTMSDataSvcRHRent/getRTMSDataSvcRHRent`) - OK
- Format: XML. `resultCode` 000 on success.
- Fields: `buildYear, contractTerm, contractType, dealDay, dealMonth, dealYear, deposit, excluUseAr, floor, houseType, jibun, mhouseNm, monthlyRent, preDeposit, preMonthlyRent, sggCd, umdNm, useRRRight`
- `deposit` uses thousands separators ("21,870"), unit 10,000 KRW. Blank values are a single space.
- `jibun` is not masked (0 of 875 rows masked in Gangseo 2024-10).
- **No legal-dong code.** Only `sggCd` (5 digits) and `umdNm` (dong name). Matching to the building register needs a dong-name to `bjdongCd` lookup (MOIS legal-dong code file).
- **No cancellation field.** Cancelled contracts disappear on re-collection.
- `contractType`: 신규 692 / 갱신 175 / blank 8. `houseType`: 다세대 828 / 연립 44 / 연립다세대 3.
- Jeonse (`monthlyRent` = 0): 400 of 875.
- `numOfRows=9999` is accepted. Largest month checked (Gangseo 2021-07) has 1,166 rows, returned in one call. One call per (district, month) is enough.

## RTMS row-house trade (`RTMSDataSvcRHTrade2/getRTMSDataSvcRHTrade2`) - OK
- Both the service and the operation name end with `2`. The old `RTMSDataSvcRHTrade/getRTMSDataSvcRHTrade` returns code 30 (key not registered); `RTMSDataSvcRHTrade2/getRTMSDataSvcRHTrade` returns code 12 (`NO_OPENAPI_SERVICE_ERROR`).
- Fields: `buildYear, buyerGbn, cdealDay, cdealType, dealAmount, dealDay, dealMonth, dealYear, dealingGbn, estateAgentSggNm, excluUseAr, floor, houseType, jibun, landAr, mhouseNm, rgstDate, sggCd, slerGbn, umdNm`
- `dealAmount` has thousands separators, unit 10,000 KRW.
- Cancellation: `cdealType` = `O` when cancelled, `cdealDay` = cancellation date as `YY.MM.DD`. Gangseo 2024-10: 20 of 223 rows cancelled.
- `rgstDate` (registration date, `YY.MM.DD`) is present on trades.
- `jibun` is not masked. Same as rent: no legal-dong code, only `umdNm`.
- Error responses use a different root element (`OpenAPI_ServiceResponse/cmmMsgHeader`), not `response/header`. The client must check both.

## Building register HUB (`BldRgstHubService`) - OK
Params: `sigunguCd, bjdongCd, platGbCd, bun (4 digits), ji (4 digits)`. Sample: Gangseo Hwagok-dong 346-82.
- `getBrRecapTitleInfo` (summary title): 1 row. Has `useAprDay` (approval date), `hhldCnt`, `mainBldCnt`, `etcPurps`.
- `getBrTitleInfo` (title): 1 row per building (`dongNm`), 2 rows here.
- `getBrExposPubuseAreaInfo` (unit areas): 58 rows. Has `dongNm, hoNm, flrNo, area, exposPubuseGbCd` (1 = exclusive). Lets us map rent rows (floor + `excluUseAr`) to candidate units. Paginate: `numOfRows` max is 100.
- `getBrHsprcInfo` (housing price): **0 rows for a multi-unit (집합) building.** Not usable for row-house public prices. Use the MOLIT multi-unit housing price file (data.go.kr 3073746).
- **No violation field** in title, summary title, basic outline or unit area responses. No Seoul-wide violating-building source exists (15160652 is Bucheon only); excluded from the MVP.
- Building PK field: `mgmBldrgstPk`.

## Open questions
- Is the daily limit per API or per key?
- Do the three Docker image tags pull?
