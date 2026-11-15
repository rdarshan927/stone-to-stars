{{flutter_js}}
{{flutter_build_config}}

function reportStartupFailure(error) {
  console.error('Flutter startup failed:', error);
  window.dispatchEvent(new Event('stone-to-stars-startup-error'));
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      // The HTML loader waits for flutter-first-frame, not this promise.
    } catch (error) {
      reportStartupFailure(error);
    }
  },
}).catch(reportStartupFailure);
