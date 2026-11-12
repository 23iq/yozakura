package client

// Names on the subscribe stream shared by the daemon and its subscribers.
const (
	// StateDumpMethod opens every subscription (and carries Features).
	StateDumpMethod = "State.Dump"
	// IdleMonitorChangedEvent reports an idle monitor flip:
	// params {id, is_idle, seq}; seq grows with every flip of any monitor.
	IdleMonitorChangedEvent = "Event.IdleMonitorChanged"
	// FeatureIdleEvents in the State.Dump features means idle monitor flips
	// are broadcast (with seq), so subscribers need not poll their state.
	FeatureIdleEvents = "idle_events"
)
