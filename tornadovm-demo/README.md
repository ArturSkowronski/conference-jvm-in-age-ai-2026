# Demo: TornadoVM (JVM → GPU/CPU akceleracja)

To jest małe, samowystarczalne demo do pokazania podczas prelekcji: to samo obliczenie uruchomione jako zwykła Java (baseline) oraz jako zadanie TornadoVM (TaskGraph).

## Wymagania

- **Baseline**: dowolny JDK 17+.
- **TornadoVM**: zainstalowany TornadoVM (np. przez SDKMAN) + działające sterowniki OpenCL/CUDA.

Szybka weryfikacja urządzeń (jeśli masz `tornado` w `PATH`):
```bash
tornado --devices
```

## Uruchomienie

### 1) Baseline (bez TornadoVM)
```bash
./scripts/run-baseline.sh --size 10000000 --iters 10
```

### 2) TornadoVM
Ustaw `TORNADO_SDK` na katalog instalacji TornadoVM (opcjonalnie, jeśli już używasz TornadoVM jako `JAVA_HOME`):
```bash
export TORNADO_SDK=~/path/to/tornadovm
./scripts/run-tornado.sh --size 10000000 --iters 10
```

## Co pokazuje demo

- Kernel w Javie + adnotacja `@Parallel`.
- Budowa `TaskGraph`, snapshot i `TornadoExecutionPlan`.
- Różnica czasów między baseline i wykonaniem TornadoVM (zależnie od urządzenia/driverów).

