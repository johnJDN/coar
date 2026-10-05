# Nutrition database for brand and restaurant foods (later)

Status: **dropped 2026-10-04 at John's request** ("I don't want to add a food database").
Noted on 2026-10-03; nothing built. Kept for the reasoning in case it comes back. If it does,
the shape discussed was a Search segment in Add Entry backed by an API at search time (not a
copy on the phone), with the picked item copied into the Entry and, with Save as food, into
Foods; manual picking avoids the wrong-product matches seen with word matching.

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
