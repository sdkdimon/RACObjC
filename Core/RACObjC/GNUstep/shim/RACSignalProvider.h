// GNUstep build only: no-op stand-in for the header Xcode generates from
// Classes/Signal/RACSignalProvider.d (DTrace probes are not used here).
// The probes are never enabled; arguments are referenced only to keep the
// helper functions that build them "used".

#define RACSIGNAL_NEXT_ENABLED() (0)
#define RACSIGNAL_NEXT(signal, subscriber, valueDescription) do { (void)(signal); (void)(subscriber); (void)(valueDescription); } while (0)

#define RACSIGNAL_COMPLETED_ENABLED() (0)
#define RACSIGNAL_COMPLETED(signal, subscriber) do { (void)(signal); (void)(subscriber); } while (0)

#define RACSIGNAL_ERROR_ENABLED() (0)
#define RACSIGNAL_ERROR(signal, subscriber, errorDescription) do { (void)(signal); (void)(subscriber); (void)(errorDescription); } while (0)
