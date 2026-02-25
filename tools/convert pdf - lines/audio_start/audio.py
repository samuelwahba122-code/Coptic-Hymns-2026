import sys
import time
import pygame
import vlc

W, H = 860, 260

def clamp(x, a, b):
    return max(a, min(b, x))

def main(audio_path: str):
    # --- VLC player (real speed control) ---
    inst = vlc.Instance()
    player = inst.media_player_new()
    media = inst.media_new_path(audio_path)
    player.set_media(media)

    # First line starts at 0ms by default
    timestamps = [0]

    # speed settings
    rate = 1.0
    RATE_MIN, RATE_MAX = 0.5, 2.5
    RATE_STEP = 0.1

    # --- Pygame window for hotkeys ---
    pygame.init()
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("Tap Sync (VLC engine) - click to focus")
    font = pygame.font.SysFont("consolas", 20)
    clock = pygame.time.Clock()

    def draw(last_mark=None, msg=None):
        screen.fill((18, 18, 22))
        lines = [
            "CLICK THIS WINDOW to focus it.",
            "Line 1 start = 0 ms (automatic)",
            "SPACE           = mark next line start",
            "NUMPAD + / -     = speed up / slow down (audio responds)",
            "ESC             = finish & print JSON pairs",
            f"Speed: {rate:.2f}x",
            f"Marks: {len(timestamps)}",
        ]
        if last_mark is not None:
            lines.append(f"Last mark: {last_mark} ms")
        if msg:
            lines.append(msg)

        y = 18
        for line in lines:
            surf = font.render(line, True, (235, 235, 235))
            screen.blit(surf, (18, y))
            y += 26
        pygame.display.flip()

    # Start playback
    if player.play() == -1:
        pygame.quit()
        raise RuntimeError("VLC failed to play the file. Check the audio path and VLC install.")

    # Wait until VLC actually starts (position becomes valid)
    t_wait_start = time.time()
    while player.get_state() in (vlc.State.Opening, vlc.State.NothingSpecial) and time.time() - t_wait_start < 3:
        time.sleep(0.02)

    player.set_rate(rate)
    draw(msg="Playing...")

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            if event.type == pygame.KEYDOWN:
                # Mark timestamp at current playback time (ms)
                if event.key == pygame.K_SPACE:
                    # VLC time is always in original timeline ms (independent of rate)
                    ms = player.get_time()
                    if ms is not None and ms >= 0:
                        timestamps.append(int(ms))
                        draw(last_mark=int(ms))

                # Numpad + / -
                elif event.key == pygame.K_KP_PLUS:
                    rate = clamp(rate + RATE_STEP, RATE_MIN, RATE_MAX)
                    ok = player.set_rate(rate)
                    draw(msg=f"Set rate -> {rate:.2f}x (ok={ok})")

                elif event.key == pygame.K_KP_MINUS:
                    rate = clamp(rate - RATE_STEP, RATE_MIN, RATE_MAX)
                    ok = player.set_rate(rate)
                    draw(msg=f"Set rate -> {rate:.2f}x (ok={ok})")

                # Also accept main keyboard +/- (optional)
                elif event.key in (pygame.K_EQUALS, pygame.K_PLUS):
                    rate = clamp(rate + RATE_STEP, RATE_MIN, RATE_MAX)
                    ok = player.set_rate(rate)
                    draw(msg=f"Set rate -> {rate:.2f}x (ok={ok})")

                elif event.key == pygame.K_MINUS:
                    rate = clamp(rate - RATE_STEP, RATE_MIN, RATE_MAX)
                    ok = player.set_rate(rate)
                    draw(msg=f"Set rate -> {rate:.2f}x (ok={ok})")

                elif event.key == pygame.K_ESCAPE:
                    running = False

        clock.tick(60)

    # Cleanup
    player.stop()
    pygame.quit()

    if len(timestamps) < 2:
        print("\nNot enough marks to create pairs.")
        print("Marks:", timestamps)
        return

    print("\n--- JSON READY PAIRS (end = next start) ---")
    for i in range(len(timestamps) - 1):
        s = timestamps[i]
        e = timestamps[i + 1]
        print(f'{{"i": {i+1}, "s": {s}, "e": {e}}},')

    print("\nLast line start (no end):", timestamps[-1])


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: py -3.12 tap_vlc_sync.py path\\to\\audio.mp3")
        raise SystemExit(1)
    main(sys.argv[1])