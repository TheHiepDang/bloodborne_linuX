// SPDX-License-Identifier: GPL-2.0-or-later
// Production FG lifecycle on a headless Vulkan device; no game data or window required.
#include <cassert>
#include <cstdio>
#include "bbport_settings.h"
#include "render/scheduler.h"
#include "textures/image.h"
#include "upscale/vk_frame_generation.h"
#include "vulkan/instance.h"

int main() {
    using namespace Vulkan;
    Instance instance(0, true);
    static vk::detail::DynamicLoader loader;
    vk::detail::DispatchLoaderDynamic dispatch;
    dispatch.init(loader.getProcAddress<PFN_vkGetInstanceProcAddr>("vkGetInstanceProcAddr"));
    dispatch.init(instance.GetInstance());
    dispatch.init(instance.GetDevice());
    Scheduler scheduler(instance);
    FrameGeneration generator(instance, scheduler);
    BbSettings::Get().frame_generation = true;
    assert(generator.Wanted()); // CI uses Lavapipe; unsupported devices are not a pass.

    struct Inputs {
        VideoCore::HostImage color, depth, motion;
        FrameGeneration::Scene scene{};
    };
    const auto make_inputs = [&](u32 size, vk::Format format) {
        Inputs inputs;
        const auto make = [&](vk::Format f, vk::ImageUsageFlags usage) {
            VideoCore::HostImage image(instance.GetDevice(), instance.GetAllocator());
            image.Create({.imageType = vk::ImageType::e2D, .format = f,
                          .extent = {size, size, 1}, .mipLevels = 1, .arrayLayers = 1,
                          .samples = vk::SampleCountFlagBits::e1, .tiling = vk::ImageTiling::eOptimal,
                          .usage = usage | vk::ImageUsageFlagBits::eSampled |
                                   vk::ImageUsageFlagBits::eTransferDst,
                          .initialLayout = vk::ImageLayout::eUndefined});
            return image;
        };
        inputs.color = make(format, vk::ImageUsageFlagBits::eStorage |
                                   vk::ImageUsageFlagBits::eTransferSrc |
                                   vk::ImageUsageFlagBits::eColorAttachment);
        inputs.motion = make(vk::Format::eR16G16Sfloat, vk::ImageUsageFlagBits::eStorage);
        inputs.depth = make(vk::Format::eD32Sfloat, vk::ImageUsageFlagBits::eTransferSrc |
                                                   vk::ImageUsageFlagBits::eDepthStencilAttachment);
        for (auto* image : {&inputs.color, &inputs.motion, &inputs.depth}) {
            const vk::Image handle = *image;
            const bool depth = image == &inputs.depth;
            scheduler.Record([handle, depth, &dispatch](vk::CommandBuffer cmd) {
                const vk::ImageSubresourceRange range{
                    depth ? vk::ImageAspectFlagBits::eDepth : vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1};
                vk::ImageMemoryBarrier2 barrier{
                    .dstStageMask = vk::PipelineStageFlagBits2::eTransfer,
                    .dstAccessMask = vk::AccessFlagBits2::eTransferWrite,
                    .oldLayout = vk::ImageLayout::eUndefined, .newLayout = vk::ImageLayout::eGeneral,
                    .image = handle, .subresourceRange = range};
                cmd.pipelineBarrier2({.imageMemoryBarrierCount = 1, .pImageMemoryBarriers = &barrier}, dispatch);
                if (depth) {
                    cmd.clearDepthStencilImage(handle, vk::ImageLayout::eGeneral,
                                                vk::ClearDepthStencilValue{0.5f, 0}, range, dispatch);
                } else {
                    cmd.clearColorImage(handle, vk::ImageLayout::eGeneral,
                                        vk::ClearColorValue{std::array<float, 4>{0, 0, 0, 0}}, range, dispatch);
                }
                barrier.srcStageMask = vk::PipelineStageFlagBits2::eTransfer;
                barrier.srcAccessMask = vk::AccessFlagBits2::eTransferWrite;
                barrier.dstStageMask = vk::PipelineStageFlagBits2::eAllCommands;
                barrier.dstAccessMask = vk::AccessFlagBits2::eMemoryRead;
                barrier.oldLayout = vk::ImageLayout::eGeneral;
                cmd.pipelineBarrier2({.imageMemoryBarrierCount = 1, .pImageMemoryBarriers = &barrier}, dispatch);
            });
        }
        inputs.scene = {.color = vk::Image(inputs.color), .color_format = format,
                        .width = size, .height = size, .depth = vk::Image(inputs.depth),
                        .depth_format = vk::Format::eD32Sfloat, .motion = vk::Image(inputs.motion),
                        .render_width = size, .render_height = size,
                        .jitter_x = 0, .jitter_y = 0, .frame_ms = 33.333f,
                        .camera_near = 0.1f, .camera_far = 3000, .vertical_fov = 1,
                        .reset = false, .camera_position = {0, 0, 0},
                        .camera_up = {0, 1, 0}, .camera_right = {1, 0, 0}, .camera_forward = {0, 0, 1}};
        return inputs;
    };
    auto small = make_inputs(128, vk::Format::eR8G8B8A8Unorm);
    auto large = make_inputs(192, vk::Format::eR8G8B8A8Unorm);
    auto reformatted = make_inputs(192, vk::Format::eR16G16B16A16Sfloat);
    const auto frame = [&](Inputs& inputs, bool expected) {
        generator.CaptureScene(inputs.scene);
        generator.CaptureHudless(inputs.scene.color);
        generator.Interpolate(inputs.scene.color, 1);
        scheduler.Finish();
        FrameGeneration::Output out{};
        assert(generator.TakeOutput(1, out) == expected);
        if (expected) {
            assert(out.width == inputs.scene.width && out.height == inputs.scene.height);
            assert(out.format == inputs.scene.color_format);
            assert(!generator.TakeOutput(1, out)); // exactly once
        }
    };
    frame(small, false); // first scene warms history
    frame(small, true);
    BbSettings::Get().frame_generation = false;
    generator.Interpolate(small.scene.color, 1); // disabled display boundary
    BbSettings::Get().frame_generation = true;
    frame(small, false);
    frame(small, true);
    generator.Invalidate(); // menu/loading: no eligible scene
    frame(small, false);
    frame(small, true);
    frame(large, false); // old HUD allocation was smaller
    frame(large, true);
    frame(reformatted, false); // same size, different format
    frame(reformatted, true);
    frame(small, false); // shrink and change format back
    frame(small, true);
    scheduler.Finish();
    std::puts("PASS: FG warmup, toggle, missing scene, once-only output, grow/shrink and format changes");
}
