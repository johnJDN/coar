# Nutrition database for brand and restaurant foods (later)

Status: noted 2026-10-03 at John's request ("eventually I'd want to add a nutrition database
as well"). Nothing built. Comes after the web-search lookup comparison
(`.scratch/ai-food-logging/lookup-test.md`).

## Why

A web-search lookup can find nothing (and used to send back 0s), find only part of a label,
or quietly give a similar product's numbers. A database holds the label itself, so the AI
only has to pick the product. Barcode scanning would come almost for free with one.

## Options named so far (not yet checked in depth)

| Source | Cost | Covers | Notes |
|---|---|---|---|
| USDA FoodData Central, Branded Foods | Free (API key, generous limits) | US packaged foods, labels sent in by manufacturers | No restaurants. Searchable by name and UPC. |
| Open Food Facts | Free | Worldwide packaged foods, crowd-sourced | Barcode-first; quality varies by product. |
| Nutritionix | Paid | Packaged and restaurant menus | |
| FatSecret Platform | Free tier, paid above | Packaged and restaurant | |
| Edamam | Paid | Packaged, recipes | |

## Open questions

- Which step it sits at: before the web search, instead of it for packaged foods, or as the
  Search segment in Add Entry (`DESIGN.md` §11 says Search is added only when a food
  database exists).
- Restaurants: the free sources mostly lack them, so web search may stay for chains.
