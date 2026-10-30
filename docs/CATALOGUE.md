# Shop catalogues

Every shop that sells things from a list uses one screen, `CatalogueScreen` (`src/ui/catalogue/`). It shows tabs of
categories over a grid of cards. Each card has a picture, a name, a short line, stats, tier pips, the price, a
requirement when it is locked, and a buy button. Page Up and Page Down switch tabs.

The shipyard (the city's ship upgrade station) and the outfitter already use it. Anything else, such as the shop
at the player's pirate lagoon, only needs a source.

## Adding a shop

1. Subclass `CatalogueSource`:

```gdscript
class_name LagoonCatalogue
extends CatalogueSource

func title_key() -> String:
	return "lagoon.shop"

func categories() -> PackedStringArray:
	return PackedStringArray(["lagoon.cat_buildings", "lagoon.cat_supplies"])

func items(s: Dictionary) -> Array[CatalogueItem]:
	var out: Array[CatalogueItem] = []
	var rum := CatalogueItem.make("rum", "lagoon.cat_supplies", Loc.t("lagoon.rum"), "pirate/bottle-large", 30)
	rum.blurb = Loc.t("lagoon.rum_desc")
	rum.stat(Loc.t("lagoon.heals"), "50")
	out.append(rum)
	var dock := CatalogueItem.make("dock", "lagoon.cat_buildings", Loc.t("lagoon.dock"), "pirate/structure-platform-dock", 4000)
	if int(s["fame"]) < 500:
		dock.lock(Loc.t("port.fame_needed") % 500)
	out.append(dock)
	return out

func buy(s: Dictionary, item: CatalogueItem) -> bool:
	# spend s["gold"], hand the item over, return false to refuse
	return true

func icon_list() -> PackedStringArray:
	return PackedStringArray(["pirate/bottle-large", "pirate/structure-platform-dock"])
```

2. Open it: `open_child(CatalogueScreen.with_source(LagoonCatalogue.new(), port_id))`, or make a
   `class_name LagoonShopScreen extends CatalogueScreen` that sets `source` in `_init()`, like `ShipyardScreen`.
3. Add the source to `CatalogueIcons.all()` and render its pictures:
   `xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/gen_catalogue_icons.gd`
   (or name just the new icons after `--`). Commit the PNGs in `assets/icons/catalogue/`.
4. Put every string in `data/i18n/strings.csv` with English and Czech.

## Item fields

| Field | Meaning |
| --- | --- |
| `id` | unique in the source; `buy_id(id)` buys it from code or tests |
| `category` | i18n key of its tab |
| `title`, `blurb` | already translated text |
| `icon` | `"kit/model"` of a Kenney model in `assets/kenney/`, or `"proc/<name>"` from `CatalogueIcons.proc_model()`; missing pictures show a letter badge |
| `stats` | `[[label, value], ...]`, added with `stat()` |
| `price` | gold; 0 shows "Free" |
| `status` | `AVAILABLE`, `LOCKED` (with `requirement`, set by `lock()`), `OWNED` or `MAXED` |
| `tier`, `tiers` | draws tier pips when `tiers > 0` |
| `action_key` | i18n key of the button, "Buy" by default |
| `data` | anything `buy()` needs; `data.trade` is the kind sent on `EventBus.trade_made` (default `catalogue`) |

The screen sends `EventBus.trade_made` and a toast after a purchase, and emits its own `bought(item)` signal.
