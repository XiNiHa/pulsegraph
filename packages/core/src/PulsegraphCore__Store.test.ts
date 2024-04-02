import { describe, expect, it } from "vitest";
import * as Store from "./PulsegraphCore__Store.gen.js";

const Value = <T>(value: T) => ({ TAG: "Value", _0: value });
const Values = <T>(values: T[]) => ({ TAG: "Values", _0: values });
const Reference = (value: string) => ({ TAG: "Reference", _0: value });
const References = (values: string[]) => ({ TAG: "References", _0: values });

describe("PulsegraphCore.Store", () => {
  describe("Correct cases", () => {
    it("new store should be empty", () => {
      const store = Store.make();
      const state = Store.getState(store);

      expect(state.size).toBe(0);
    });

    it("correctly commits simple payload", () => {
      const store = Store.make();
      const payload = { data: { foo: 10 } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: { foo: { content: Value(10), commitedAt: expect.any(Number) } },
      });
    });

    it("correctly commits object without id", () => {
      const store = Store.make();
      const payload = { data: { foo: { bar: 10 } } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Reference("root:foo"),
            commitedAt: expect.any(Number),
          },
        },
        "root:foo": {
          bar: { content: Value(10), commitedAt: expect.any(Number) },
        },
      });
    });

    it("correctly commits object with string id", () => {
      const store = Store.make();
      const payload = { data: { foo: { id: "duh", bar: 10 } } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: { content: Reference("duh"), commitedAt: expect.any(Number) },
        },
        duh: {
          id: { content: Value("duh"), commitedAt: expect.any(Number) },
          bar: { content: Value(10), commitedAt: expect.any(Number) },
        },
      });
    });

    it("correctly commits object with int id", () => {
      const store = Store.make();
      const payload = { data: { foo: { id: 1, bar: 10 } } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: { content: Reference("1"), commitedAt: expect.any(Number) },
        },
        "1": {
          id: { content: Value(1), commitedAt: expect.any(Number) },
          bar: { content: Value(10), commitedAt: expect.any(Number) },
        },
      });
    });

    it("correctly commits top level array with scalars", () => {
      const store = Store.make();
      const payload = { data: { foo: [10] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: { content: Values([10]), commitedAt: expect.any(Number) },
        },
      });
    });

    it("correctly commits top level array with objects without id", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ bar: 10 }] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: References(["root:foo:0"]),
            commitedAt: expect.any(Number),
          },
        },
        "root:foo:0": {
          bar: {
            content: Value(10),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with objects with string id", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ id: "duh", bar: 10 }] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: References(["duh"]),
            commitedAt: expect.any(Number),
          },
        },
        duh: {
          id: {
            content: Value("duh"),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Value(10),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with objects with int id", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ id: 1, bar: 10 }] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: References(["1"]),
            commitedAt: expect.any(Number),
          },
        },
        "1": {
          id: {
            content: Value(1),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Value(10),
            commitedAt: expect.any(Number),
          },
        },
      });
    });
  });

  describe("Incorrect cases", () => {
    it("errors on array with mixed types", () => {
      const store = Store.make();
      const payload = { data: { foo: [10, "bar"] } };

      const result = Store.commitPayload(store, payload);
      expect(result).toEqual({
        TAG: "Error",
        _0: [`Array of mixed types at "root"`],
      });
    });

    it("errors on nested arrays", () => {
      const store = Store.make();
      const payload = { data: { foo: [[10]] } };

      const result = Store.commitPayload(store, payload);
      expect(result).toEqual({
        TAG: "Error",
        _0: [`Array of unknown or invalid types at "root"`],
      });
    });
  });
});
