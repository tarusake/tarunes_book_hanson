#include "Vtarunes_top.h"
#include <SDL2/SDL.h>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "verilated.h"
#include "verilated_fst_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init Error: %s\n", SDL_GetError());
        return EXIT_FAILURE;
    }

    constexpr int SCREEN_WIDTH  = 256;
    constexpr int SCREEN_HEIGHT = 240;
    constexpr int SCALE         = 2;

    SDL_Window* window = SDL_CreateWindow(
        "tarunes", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        SCREEN_WIDTH * SCALE, SCREEN_HEIGHT * SCALE, SDL_WINDOW_SHOWN);
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

    uint32_t pixel_buffer[SCREEN_HEIGHT][SCREEN_WIDTH];
    memset(pixel_buffer, 0, sizeof(pixel_buffer));

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
        int pixel_r  = dut->pixel_r;
        int pixel_g  = dut->pixel_g;
        int pixel_b  = dut->pixel_b;

        if (cycle < SCREEN_WIDTH && scanline < SCREEN_HEIGHT) {
            pixel_buffer[scanline][cycle] =
                0xFF000000 |
                ((pixel_r & 0xFF) << 16) |
                ((pixel_g & 0xFF) << 8) |
                (pixel_b & 0xFF);
        }

        if (prev_scanline == 261 && scanline == 0) {
            frame_count++;
            SDL_UpdateTexture(
                texture, nullptr, pixel_buffer,
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
