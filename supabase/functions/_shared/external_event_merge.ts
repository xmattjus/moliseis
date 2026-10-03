import type {
  CanonicalEventProjection,
  NormalizedExternalEvent,
} from "./external_event_normalization.ts";

export const EVENT_MERGE_GROUP_FIELDS = {
  name: ["name"],
  category: ["category"],
  description: ["description", "description_delta"],
  schedule: ["start_date", "end_date", "all_day"],
  location: ["city", "latitude", "longitude"],
} as const;
export type EventMergeGroup = keyof typeof EVENT_MERGE_GROUP_FIELDS;
export type EventGroupValues = Partial<CanonicalEventProjection>;
export type EventMergeGroupState = {
  group: EventMergeGroup;
  provider_changed: boolean;
  moderator_changed: boolean;
  apply: boolean;
  overwrite: boolean;
  base: EventGroupValues;
  source: EventGroupValues;
  moderated: EventGroupValues;
  current: EventGroupValues;
};
export type ExternalEventMerge = {
  groups: EventMergeGroupState[];
  groups_to_apply: EventMergeGroup[];
};

/** Inputs have passed the sole shared canonicalizer; compare complete atomic groups. */
export function calculateExternalEventMerge(
  base: NormalizedExternalEvent,
  source: NormalizedExternalEvent,
  moderated: NormalizedExternalEvent,
  event: CanonicalEventProjection,
): ExternalEventMerge {
  const groups = (Object.keys(EVENT_MERGE_GROUP_FIELDS) as EventMergeGroup[])
    .map((group) => {
      const project = (value: CanonicalEventProjection): EventGroupValues =>
        Object.fromEntries(
          EVENT_MERGE_GROUP_FIELDS[group].map((field) => [field, value[field]]),
        );
      const b = project(base),
        s = project(source),
        m = project(moderated),
        e = project(event);
      const equal = (left: EventGroupValues, right: EventGroupValues) =>
        JSON.stringify(left) === JSON.stringify(right);
      const provider_changed = !equal(s, b), moderator_changed = !equal(m, s);
      const apply = provider_changed || moderator_changed;
      return {
        group,
        provider_changed,
        moderator_changed,
        apply,
        overwrite: apply && !equal(e, b) && !equal(e, m),
        base: b,
        source: s,
        moderated: m,
        current: e,
      };
    });
  return {
    groups,
    groups_to_apply: groups.filter((group) => group.apply).map((group) =>
      group.group
    ),
  };
}
