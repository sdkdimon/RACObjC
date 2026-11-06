# Known failures on GNUstep

The specs below fail on GNUstep. `gmake check` passes this file to the spec
run (`QUICK_KNOWN_FAILURES`, see `QuickNimble/Quick.m`). An entry is a list
item that holds only a code span; headings and text are ignored.

| Entry | Effect |
|---|---|
| `SpecClass.test_method` | Runs. Its failures are logged, not recorded, and the run fails if it passes. |
| `skip SpecClass.test_method` | Doesn't run, because it can bring the process down. |
| `aarch64 SpecClass.test_method` | Applies only on aarch64. |
| `x86_64 SpecClass.test_method` | Applies only on x86_64. |

`skip` and an architecture can be combined: `skip aarch64 SpecClass.test_method`.

Test method names are the ones xctest prints, e.g.
`-[RACSignalSpec memory_management__should_dealloc_...]`. A listed test that
doesn't exist fails the run, on every architecture.

Measured 2026-11-05 on Linux aarch64 with gnustep-base 1.31.1 and with
gnustep-base master (Gershwin's pins), which fail the same tests, and on
x86_64 (emulated) with 1.31.1. Fix one, then remove its entry.

## Concurrent KVO aborts the process

gnustep-base's `-removeObserver:forKeyPath:context:` throws when KVO
observations are added and removed concurrently, which aborts the process
(about 6 runs in 10).

- `skip RACKVOProxySpec.RACKVOProxy__stress__async_disposal_of_observer`

## NSDictionary sequences

The expected values come from enumerating the dictionary, but `-rac_sequence`
(and the key and value sequences) enumerate a copy, which gnustep-base
enumerates in a different order. An assumption of the specs, not a RAC bug.

- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples___signalWithScheduler___should_return_a_background_scheduled_signal`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples___signalWithScheduler___should_return_an_immediately_scheduled_signal`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples__should_be_equal_to_the_same_sequence_of_values`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples__should_fold_left`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples__should_fold_right`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples__should_implement__NSFastEnumeration_`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__RACSequenceExamples__should_return_an_array`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples___signalWithScheduler___should_return_a_background_scheduled_signal`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples___signalWithScheduler___should_return_an_immediately_scheduled_signal`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples__should_be_equal_to_the_same_sequence_of_values`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples__should_fold_left`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples__should_fold_right`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples__should_implement__NSFastEnumeration_`
- `RACSequenceAdditionsSpec.NSDictionary_sequences__should_be_immutable__RACSequenceExamples__should_return_an_array`

## Objects that aren't deallocated

Not investigated yet. An object that should be deallocated isn't: the spec's
dealloc flag stays `NO`, or a weak reference stays set.

- `NSObjectRACSelectorSignalSpec.RACTestObject__should_send_completed_on_deallocation`
- `RACKVOChannelSpec.RACKVOChannel__should_deallocate_when_the_target_deallocates`

## Objects that aren't deallocated, aarch64 only

Not investigated yet. As above, but these pass on x86_64. It isn't ARC's
return-value handoff, which works on both.

- `aarch64 NSObjectRACPropertySubscribingSpec._rac_valuesForKeyPath_observer___RACPropertySubscribingExamples__shouldn_t_keep_the_signal_alive_past_the_lifetime_of_the_object`
- `aarch64 RACKVOWrapperSpec.rac_addObserver_forKeyPath_options_block___should_automatically_stop_KVO_when_the_observer_deallocates`
- `aarch64 RACSequenceSpec._objectEnumerator__should_let_the_sequence_dealloc_as_it_s_enumerated`
- `aarch64 RACSignalSpec._bind___should_not_retain_signals_that_are_subscribed`
- `aarch64 RACSignalSpec._combineLatestWith___shouldn_t_create_a_retain_cycle`
- `aarch64 RACSignalSpec._flatten___shouldn_t_create_a_retain_cycle`
- `aarch64 RACSignalSpec.memory_management__should_dealloc_a_replay_subject_if_it_completes_immediately`
- `aarch64 RACSignalSpec.memory_management__should_dealloc_if_the_signal_was_created_on_a_background_queue`
- `aarch64 RACSignalSpec.memory_management__should_dealloc_signals_if_the_signal_immediately_completes`

## KVO on a deallocating target

Not investigated yet. The callback that should run while the target
deallocates never gets its identifier.

- `RACKVOWrapperSpec.rac_addObserver_forKeyPath_options_block___automatically_stops_KVO_on_subclasses_when_the_target_deallocates__stops_KVO_on_NSObject_subclasses`
- `RACKVOWrapperSpec.rac_addObserver_forKeyPath_options_block___automatically_stops_KVO_on_subclasses_when_the_target_deallocates__stops_KVO_on_NSObject_subclasses_even_with_a_nil_observer`
- `RACKVOWrapperSpec.rac_addObserver_forKeyPath_options_block___automatically_stops_KVO_on_subclasses_when_the_target_deallocates__stops_KVO_on_subclasses_of_already_swizzled_classes`
- `RACKVOWrapperSpec.rac_addObserver_forKeyPath_options_block___automatically_stops_KVO_on_subclasses_when_the_target_deallocates__stops_KVO_on_subclasses_of_already_swizzled_classes_even_with_a_nil_observer`

## Signals and terminals that don't complete

Not investigated yet. A signal or terminal that should complete doesn't.

- `RACChannelSpec.RACChannel__RACChannelExamples__should_complete_both_signals_when_the_followingTerminal_is_completed`
- `RACChannelSpec.RACChannel__RACChannelExamples__should_complete_both_signals_when_the_leadingTerminal_is_completed`
- `RACKVOChannelSpec.RACKVOChannel__RACChannelExamples__should_complete_both_signals_when_the_followingTerminal_is_completed`
- `RACKVOChannelSpec.RACKVOChannel__RACChannelExamples__should_complete_both_signals_when_the_leadingTerminal_is_completed`
- `RACKVOChannelSpec.RACKVOChannel__should_complete_both_terminals_when_the_target_deallocates`
- `RACSequenceSpec.shouldn_t_overflow_the_stack_when_deallocated_on_a_background_queue`
- `RACSignalSpec._if_then_else__should_send_completed_when_the_BOOL_signal_and_the_latest_sent_signal_complete`
- `RACSignalSpec._switchToLatest__should_send_completed_when_the_switching_signal_completes_and_the_last_sent_signal_does`

## RACCommand and the main thread scheduler

Not investigated yet. Values aren't delivered on, or don't reach, the main
thread scheduler: `enabled` stays `YES`, and errors and the updating scheduler
never arrive.

- `RACCommandSpec.enabled_signal__should_always_update_on_the_main_thread`
- `RACCommandSpec.enabled_signal__should_complete_when_the_command_is_deallocated_even_if_the_input_signal_hasn_t`
- `RACCommandSpec.enabled_signal__should_send_NO_while_executing_is_YES_and_allowsConcurrentExecution_is_NO`
- `RACCommandSpec.enabled_signal__should_send_whatever_the_enabledSignal_has_sent_most_recently`
- `RACCommandSpec.should_deliver_errors_onto__errors_`
- `RACCommandSpec.with_a_simple_signal_block__should_always_update_executing_on_the_main_thread`
- `RACCommandSpec.with_a_simple_signal_block__should_complete_signals_on_the_main_thread_when_deallocated`

## Values sent once instead of twice

Not investigated yet.

- `RACSignalSpec._switch_cases_default___should_use_the_default_signal_if_key_that_was_sent_does_not_have_an_associated_signal`
- `RACSubjectSpec.RACReplaySubject__with_a_capacity_of_1__should_send_same_latest_value_to_multiple_subscribers_in_another_subscription`

## respondsToSelector: for an injected optional method

Not investigated yet. `-respondsToSelector:` is `YES` for an optional protocol
method injected on another instance of the class.

- `NSObjectRACSelectorSignalSpec.RACTestObject__should_properly_implement__respondsToSelector__for_optional_method_from_a_protocol`
