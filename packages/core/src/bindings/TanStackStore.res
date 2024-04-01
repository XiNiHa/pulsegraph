type t<'state, 'updater>

type listener = unit => unit

type optionsWithoutUpdater<'state, 'updater> = {
  onSubscribe?: (listener, t<'state, 'updater>) => unit => unit,
  onUpdate?: listener,
}

type optionsWithUpdater<'state, 'updater> = {
  ...optionsWithoutUpdater<'state, 'updater>,
  updateFn: 'state => 'updater => 'state,
}

type options<'state, 'updater> = {
  ...optionsWithoutUpdater<'state, 'updater>,
  updateFn?: 'state => 'updater => 'state,
}

@new @module("@tanstack/store")
external make: (
  ~initialState: 'state,
  ~options: option<optionsWithoutUpdater<'state, 'state => 'state>>=?,
) => t<'state, 'state => 'state> = "Store"
@new @module("@tanstack/store")
external makeWithUpdater: (
  ~initialState: 'state,
  ~options: optionsWithUpdater<'state, 'updater>,
) => t<'state, 'updater> = "Store"

@get external state: t<'state, 'updater> => 'state = "state"
@get external listeners: t<'state, 'updater> => Set.t<listener> = "listeners"
@get external options: t<'state, 'updater> => option<options<'state, 'updater>> = "options"

@send external subscribe: (t<'state, 'updater>, listener) => unit => unit = "subscribe"
@send external setState: (t<'state, 'updater>, 'updater) => unit = "setState"
@send external batch: (t<'state, 'updater>, unit => unit) => unit = "batch"
