---
name: firmware-embedded
category: embedded
public: false
database: none
hosting_hints:
  - bare-metal
  - microcontroller-flash
  - ota-server
audit_stack:
  - analyze
  - code-clean
  - cso
  - doc
plugins:
  context7: no
  ui-ux-pro-max: no
  gstack: no
---

# Firmware / Embedded

Projet firmware bas-niveau / microcontrôleur (STM32, ESP32, RP2040, Nordic, AVR). Pas de système d'exploitation complet (bare-metal / RTOS léger type FreeRTOS/Zephyr).

## Detection signals

### Strong signals (×3)
- FILE: `platformio.ini` (PlatformIO)
- FILE: `*.ld` OR `*.lds` OR `linker*.ld` (linker scripts — signature bare-metal)
- FILE: `CMakeLists.txt` contenant "arm-none-eabi" OR "riscv-none-elf" OR "xtensa-esp32" OR "ESP_PLATFORM" OR "STM32"
- FILE: `Kconfig` (Zephyr RTOS)

### Medium signals (×2)
- FILE: `Makefile` avec variables CC / AS / LD / OBJCOPY
- DIR: `src/` avec fichiers .c / .cpp / .h ET absence de manifests langage haut-niveau (pas de package.json, Cargo.toml, go.mod, pyproject.toml)
- DIR: `drivers/` OR `hal/` OR `bsp/` OR `mcu/`
- FILE: `sdkconfig` (ESP-IDF)
- FILE: `prj.conf` (Zephyr)
- FILE: `idf_component.yml` (ESP-IDF component)

### Weak signals (×1)
- FILE: `openocd.cfg` (debug probe config)
- FILE: `*.cfg` contenant "adapter" OR "interface" OR "transport select"
- EXT: outputs `.bin`, `.hex`, `.uf2`, `.elf` dans un `build/` ou `.pio/`
- DEP (platformio): "[env:*]" sections

### Counter-signals (exclusion)
- FILE: `package.json` AVEC deps JavaScript → app web (pas embedded)
- FILE: `Cargo.toml` AVEC `[dependencies]` bibliothèques hautes → peut être Rust embedded (créer archetype rust-embedded plus tard)
- FILE: `.c` files AVEC `pyproject.toml` / `Cargo.toml` contenant pybind/pyo3 → FFI bindings, PAS embedded

## Implications
- **Cible** : microcontrôleur (STM32/ESP32/RP2040/nRF/AVR/MSP430) / SoC bas-niveau / bare-metal
- **Base de données** : aucune (stockage = flash interne / EEPROM / SD card brute)
- **SEO/GEO** : N/A
- **Surface sécurité** : SPÉCIFIQUE — buffer overflows stack/heap, secure boot, OTA integrity, JTAG exposé, downgrade attacks
- **UI/UX** : N/A (sauf petits LCD/OLED)

## Typical pain points
- Buffer overflows : `strcpy`, `strcat`, `sprintf` sans bounds check
- `malloc` dans ISR / sections critiques (hang potentiel)
- Pas de watchdog timer activé
- Optim compiler `-O0` ou `-O3` sans profil (bugs volatile manquent)
- `volatile` oublié sur MMIO / variables partagées ISR-main
- Pas de `-Wall -Wextra -Wpedantic` + `-Werror`
- Linker script maison non audité (sections overlap / alignement incorrect)
- Stack size insuffisant (crash silencieux par overflow)
- Secrets / keys en dur dans le binaire (extractibles par dump flash)
- Secure Boot / signing non activé
- OTA sans vérification signature → persistant firmware malveillant possible
- JTAG / SWD non désactivé en prod → extraction firmware / inject code
- Debug logs activés en release (`printf` via UART exposé)
- Ressources cycles hardcoded (sleeps en loops `for`) → non portable à autre horloge
- Pas d'abstraction HAL → couplage MCU-specific partout
- Timings critiques non mesurés (analyseur logique absent du workflow)
- Energy profile ignoré (wake-up patterns sous-optimaux, sleep modes inutilisés)
- Pas de tests unitaires (on-host avec mocks HAL absent)
- CI sans cross-compilation (`arm-none-eabi-gcc` non disponible)
- Documentation registres absente (cf datasheet + magic numbers dans le code)
- Flash wear leveling ignoré (écritures fréquentes sur même secteur)

## Interview questions (adaptive)
En plus du set minimum business :
- MCU / SoC cible : famille (STM32Fxx / ESP32-S3 / RP2040 / nRF52 / autre) ?
- Toolchain : GNU ARM / ESP-IDF / Zephyr / PlatformIO / Arduino / autre ?
- Framework / RTOS : bare-metal / FreeRTOS / Zephyr / Mbed / Arduino / ESP-IDF ?
- HAL / BSP : vendor HAL / CMSIS / libopencm3 / custom ?
- Langage : C / C++ / Rust embedded / Ada ?
- Standard C version (C99 / C11 / C17) + flags GCC ?
- Secure Boot activé ? Signing firmware ?
- OTA : présent / comment (MQTT / HTTP / custom) / signature vérifiée ?
- Debug : JTAG / SWD en prod (devrait être désactivé) ?
- Watchdog actif ? reset sources tracées ?
- Power budget : ampérage / sleep modes utilisés ?
- Memory budget : flash size / RAM size / current usage ?
- Tests : on-host (Unity/CMocka/etc.) / on-target / HIL (hardware-in-loop) ?
- CI : cross-compile + tests on-host ? lint (cppcheck, clang-tidy) ?
- MISRA-C / CERT-C conformance ?
- Product certifications visées (FCC / CE / CE-RED / FIPS / IEC 62443) ?
- Bootloader : custom / vendor / MCUboot ?
- Logs prod : UART / RTT / deep-ignored ?

## Plugin recommendations
- **context7** : OFF — docs MCU (datasheets, ref manuals) PDF, hors scope context7
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout (PlatformIO STM32)
```
platformio.ini
include/
  config.h
src/
  main.c
  drivers/
    uart.c
    i2c.c
    gpio.c
  hal/
    stm32f4xx_it.c
  rtos/
    tasks.c
  app/
    sensor.c
    protocol.c
lib/
  external/
test/
  test_sensor.c
docs/
  datasheets/
```
