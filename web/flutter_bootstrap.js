{{flutter_js}}
{{flutter_build_config}}

// Use HTML renderer globally to fix CORS issues with external images.
// CanvasKit is strict about cross-origin image data; HTML uses native <img> tags.
const renderer = 'html';

_flutter.loader.load({
  renderer: renderer,
  onEntrypointLoaded: async function (engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine({
      renderer: renderer,
    });
    await appRunner.runApp();
  },
});
