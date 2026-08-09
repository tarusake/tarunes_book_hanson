#include "Vtarunes_top.h"
#include <SDL2/SDL.h>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include "verilated.h"
#include "verilated_fst_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init Error: %s\n", SDL_GetError());
        return EXIT_FAILURE;
    }

    constexpr int NES_WIDTH = 256;
    constexpr int NES_HEIGHT = 240;
    constexpr int HDMI_WIDTH = 720;
    constexpr int HDMI_HEIGHT = 480;
    constexpr int SCALE         = 2;

    bool capture_hdmi = false;
    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[i], "--capture-hdmi") == 0) {
            capture_hdmi = true;
        }
    }

    const int SCREEN_WIDTH = capture_hdmi ? HDMI_WIDTH : NES_WIDTH;
    const int SCREEN_HEIGHT = capture_hdmi ? HDMI_HEIGHT : NES_HEIGHT;

    SDL_Window* window = SDL_CreateWindow(
        "tarunes", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        SCREEN_WIDTH * (capture_hdmi ? 1 : SCALE),
        SCREEN_HEIGHT * (capture_hdmi ? 1 : SCALE), SDL_WINDOW_SHOWN);
    if (window == nullptr) {
        fprintf(stderr, "SDL_CreateWindow Error: %s\n", SDL_GetError());
        SDL_Quit();
        return EXIT_FAILURE;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(
        window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (renderer == nullptr) {
        fprintf(stderr, "SDL_CreateRenderer Error: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return EXIT_FAILURE;
    }

    SDL_Texture* texture = SDL_CreateTexture(
        renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
        SCREEN_WIDTH, SCREEN_HEIGHT);
    if (texture == nullptr) {
        fprintf(stderr, "SDL_CreateTexture Error: %s\n", SDL_GetError());
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return EXIT_FAILURE;
    }

    std::vector<uint32_t> pixel_buffer(
        SCREEN_WIDTH * SCREEN_HEIGHT, 0);

    Vtarunes_top* dut = new Vtarunes_top;
    VerilatedFstC* tfp = new VerilatedFstC;
    dut->trace(tfp, 99);
    tfp->open("wave.fst");

    dut->clk = 0;
    dut->rst = 0;

    constexpr int RESET_CYCLES = 4;
    constexpr int SIM_CYCLES   = 341 * 262 * 10;
    int prev_scanline           = 0;
    int frame_count             = 0;

    for (int sim_cycle = 0; sim_cycle < SIM_CYCLES; sim_cycle++) {
        if (sim_cycle == RESET_CYCLES)
            dut->rst = 1;

        dut->clk = 0;
        dut->eval();
        tfp->dump(Verilated::time());
        Verilated::timeInc(1);

        dut->clk = 1;
        dut->eval();
        tfp->dump(Verilated::time());
        Verilated::timeInc(1);

        int scanline = dut->scanline;
        int cycle    = dut->cycle;

        if (capture_hdmi) {
            int hdmi_x = dut->hdmi_video_x;
            int hdmi_y = dut->hdmi_video_y;
            if (dut->hdmi_de
                && hdmi_x < SCREEN_WIDTH
                && hdmi_y < SCREEN_HEIGHT) {
                pixel_buffer[hdmi_y * SCREEN_WIDTH + hdmi_x] =
                    0xFF000000 |
                    ((dut->hdmi_r & 0xFF) << 16) |
                    ((dut->hdmi_g & 0xFF) << 8) |
                    (dut->hdmi_b & 0xFF);
            }
        } else if (cycle < SCREEN_WIDTH && scanline < SCREEN_HEIGHT) {
            pixel_buffer[scanline * SCREEN_WIDTH + cycle] =
                0xFF000000 |
                ((dut->pixel_r & 0xFF) << 16) |
                ((dut->pixel_g & 0xFF) << 8) |
                (dut->pixel_b & 0xFF);
        }

        if (prev_scanline == 261 && scanline == 0) {
            frame_count++;
            SDL_UpdateTexture(
                texture, nullptr, pixel_buffer.data(),
                SCREEN_WIDTH * sizeof(uint32_t));
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, nullptr, nullptr);
            SDL_RenderPresent(renderer);
        }
        prev_scanline = scanline;
    }

    tfp->close();
    delete dut;
    delete tfp;

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
