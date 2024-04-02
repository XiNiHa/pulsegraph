import { describe, expect, it } from "vitest";
import * as Store from "./PulsegraphCore__Store.gen.js";
import * as GraphQL from "./PulsegraphCore__GraphQL.gen.js";

const Scalar = (value: GraphQL.Scalar_t) => ({ TAG: "Scalar", _0: value });
const Error = (error: GraphQL.Response_error) => ({ TAG: "Error", _0: error });
type Scalar = ReturnType<typeof Scalar>;
type Error = ReturnType<typeof Error>;
type Value = Scalar | Error;

const Value = (value: Value) => ({ TAG: "Value", _0: value });
const Values = (values: Value[]) => ({ TAG: "Values", _0: values });
const Reference = (value: string) => ({ TAG: "Reference", _0: value });
const References = (values: (string | null)[]) => ({
  TAG: "References",
  _0: values,
});

describe("PulsegraphCore.Store", () => {
  describe("Correct cases", () => {
    it("new store should be empty", () => {
      const store = Store.make();
      const state = Store.getState(store);

      expect(state.size).toBe(0);
    });

    it("correctly commits a scalar", () => {
      const store = Store.make();
      const payload = { data: { foo: 10 } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Value(Scalar(10)),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits null", () => {
      const store = Store.make();
      const payload = { data: { foo: null } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Value(Scalar(null)),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits object without id", () => {
      const store = Store.make();
      const payload = { data: { foo: { bar: 10, baz: null } } };

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
          bar: { content: Value(Scalar(10)), commitedAt: expect.any(Number) },
          baz: { content: Value(Scalar(null)), commitedAt: expect.any(Number) },
        },
      });
    });

    it("correctly commits object with string id", () => {
      const store = Store.make();
      const payload = { data: { foo: { id: "duh", bar: 10, baz: null } } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: { content: Reference("duh"), commitedAt: expect.any(Number) },
        },
        duh: {
          id: { content: Value(Scalar("duh")), commitedAt: expect.any(Number) },
          bar: { content: Value(Scalar(10)), commitedAt: expect.any(Number) },
          baz: { content: Value(Scalar(null)), commitedAt: expect.any(Number) },
        },
      });
    });

    it("correctly commits object with int id", () => {
      const store = Store.make();
      const payload = { data: { foo: { id: 1, bar: 10, baz: null } } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: { content: Reference("1"), commitedAt: expect.any(Number) },
        },
        "1": {
          id: { content: Value(Scalar(1)), commitedAt: expect.any(Number) },
          bar: { content: Value(Scalar(10)), commitedAt: expect.any(Number) },
          baz: { content: Value(Scalar(null)), commitedAt: expect.any(Number) },
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
          foo: {
            content: Values([Scalar(10)]),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with nulls", () => {
      const store = Store.make();
      const payload = { data: { foo: [null] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Values([Scalar(null)]),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with scalars and nulls", () => {
      const store = Store.make();
      const payload = { data: { foo: [10, null] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Values([Scalar(10), Scalar(null)]),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with objects without id", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ bar: 10, baz: null }] } };

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
            content: Value(Scalar(10)),
            commitedAt: expect.any(Number),
          },
          baz: {
            content: Value(Scalar(null)),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with objects with string id", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ id: "duh", bar: 10, baz: null }] } };

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
            content: Value(Scalar("duh")),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Value(Scalar(10)),
            commitedAt: expect.any(Number),
          },
          baz: {
            content: Value(Scalar(null)),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with objects with int id", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ id: 1, bar: 10, baz: null }] } };

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
            content: Value(Scalar(1)),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Value(Scalar(10)),
            commitedAt: expect.any(Number),
          },
          baz: {
            content: Value(Scalar(null)),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly commits top level array with objects without id and null", () => {
      const store = Store.make();
      const payload = { data: { foo: [{ bar: 10, baz: null }, null] } };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: References(["root:foo:0", null]),
            commitedAt: expect.any(Number),
          },
        },
        "root:foo:0": {
          bar: {
            content: Value(Scalar(10)),
            commitedAt: expect.any(Number),
          },
          baz: {
            content: Value(Scalar(null)),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly handles top level errors", () => {
      const store = Store.make();
      const payload = {
        data: { foo: null },
        errors: [{ message: "error", path: ["foo"] }],
      };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Value(Error({ message: "error", path: ["foo"] })),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly handles errors in top level arrays", () => {
      const store = Store.make();
      const payload = {
        data: { foo: [null] },
        errors: [{ message: "error", path: ["foo", 0] }],
      };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Values([Error({ message: "error", path: ["foo", 0] })]),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly handles errors in objects without id", () => {
      const store = Store.make();
      const payload = {
        data: { foo: { bar: null } },
        errors: [{ message: "error", path: ["foo", "bar"] }],
      };

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
          bar: {
            content: Value(Error({ message: "error", path: ["foo", "bar"] })),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly handles errors in objects with string id", () => {
      const store = Store.make();
      const payload = {
        data: { foo: { id: "duh", bar: null } },
        errors: [{ message: "error", path: ["foo", "bar"] }],
      };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Reference("duh"),
            commitedAt: expect.any(Number),
          },
        },
        duh: {
          id: {
            content: Value(Scalar("duh")),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Value(Error({ message: "error", path: ["foo", "bar"] })),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly handles errors in objects with int id", () => {
      const store = Store.make();
      const payload = {
        data: { foo: { id: 1, bar: null } },
        errors: [{ message: "error", path: ["foo", "bar"] }],
      };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Reference("1"),
            commitedAt: expect.any(Number),
          },
        },
        "1": {
          id: {
            content: Value(Scalar(1)),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Value(Error({ message: "error", path: ["foo", "bar"] })),
            commitedAt: expect.any(Number),
          },
        },
      });
    });

    it("correctly handles errors in nested objects with id", () => {
      const store = Store.make();
      const payload = {
        data: { foo: { id: "meh", bar: { id: "duh", baz: null } } },
        errors: [{ message: "error", path: ["foo", "bar", "baz"] }],
      };

      Store.commitPayload(store, payload);
      const map = Store.getState(store);
      const state = Object.fromEntries(map.entries());

      expect(state).toEqual({
        root: {
          foo: {
            content: Reference("meh"),
            commitedAt: expect.any(Number),
          },
        },
        meh: {
          id: {
            content: Value(Scalar("meh")),
            commitedAt: expect.any(Number),
          },
          bar: {
            content: Reference("duh"),
            commitedAt: expect.any(Number),
          },
        },
        duh: {
          id: {
            content: Value(Scalar("duh")),
            commitedAt: expect.any(Number),
          },
          baz: {
            content: Value(
              Error({ message: "error", path: ["foo", "bar", "baz"] }),
            ),
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
