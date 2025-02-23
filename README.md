# Tyler

![screenshot](screenshot.png)

A tilemap editor written in Odin with Raylib.

## Requirements

- [odin](https://odin-lang.org/)
- [make](https://www.gnu.org/software/make/)

## Running

```bash
make run
```

## Todo

- [ ] scroll tile UI
    - [ ] load spritesheet
    - [ ] cut out tiles into 1D array
    - [ ] reshape into 2D target array
    - [ ] build a texture from the 2D array
    - [ ] draw the texture into the UI, cutting off `src` as it scrolls
    - [ ] ensure that the mouse to tile mapping works with scrolling
- [ ] multi tile selection
    - [ ] randomly place tiles from multi selection
- [ ] reselectable/editable tiles
- [ ] layers of tiles
- [ ] adding colliders
- [ ] bucket tool
- [ ] scale slider
- [ ] adjustable map size
- [ ] UI panels draggable
- [ ] toggle grid on/off
- [ ] debug UI on right
- [x] paint tool
- [x] remove placed tiles
- [x] drag and pan with mouse
