import { atom, WritableAtom } from 'nanostores'
import { match, P } from 'ts-pattern'

export interface Node {
  __typename: string
  id: string
}

export interface CreateCacheOptions {
  initialData?: Record<string, Record<string, unknown>>
  diffFn?: (a: unknown, b: unknown) => boolean
}

export type Cache = ReturnType<typeof createCache>
type CacheEntry = Record<string, WritableAtom | WritableAtom[]>

export const getGID = (
  obj: Record<string, unknown>,
  path: (string | number)[]
) => {
  if ('id' in obj && typeof obj.id === 'string') return obj.id
  else return path.join(':')
}

export const createCache = (options?: CreateCacheOptions) => {
  const cacheMap = new Map<string, WritableAtom<CacheEntry>>()
  const defaultDiffFn = (a: unknown, b: unknown) => a === b

  if (options?.initialData) {
    for (const [gid, node] of Object.entries(options.initialData)) {
      const nodeRecord = Object.create(null)
      cacheMap.set(gid, nodeRecord)

      for (const [key, value] of Object.entries(node)) {
        nodeRecord[key] = atom(value)
      }
    }
  }

  return {
    get(gid: string) {
      const nodeRecord = cacheMap.get(gid)
      return nodeRecord && { ...nodeRecord.get() }
    },
    set(obj: Record<string, unknown>, path: (string | number)[]) {
      const gid = getGID(obj, path)
      const nodeRecord =
        cacheMap.get(gid) ??
        (() => {
          const nodeMap: WritableAtom<CacheEntry> = atom(Object.create(null))
          cacheMap.set(gid, nodeMap)
          return nodeMap
        })()

      for (const [key, value] of Object.entries(obj) as [string, unknown][]) {
        const currentAtom = nodeRecord.get()[key]
        const diffFn = options?.diffFn ?? defaultDiffFn

        type Candidate = { atom: WritableAtom } | { value: unknown }
        const getCand = (
          value: unknown,
          path: (string | number)[]
        ): Candidate => {
          if (typeof value === 'object' && value !== null) {
            const record = value as Record<string, unknown>
            return { atom: this.set(record, [getGID(record, path)]) }
          } else return { value }
        }
        const cand = (() => {
          if (Array.isArray(value)) {
            return value.map((item: unknown, i) => getCand(item, [...path, i]))
          } else {
            return getCand(value, path)
          }
        })()

        if (!currentAtom) {
          const store = (cand: Candidate) =>
            void match(cand)
              .with(
                { atom: P.any },
                ({ atom }) => (nodeRecord.get()[key] = atom)
              )
              .with(
                { value: P.any },
                ({ value }) => (nodeRecord.get()[key] = atom(value))
              )
              .run()

          if (Array.isArray(cand)) cand.map(store)
          else store(cand)
        } else {
          if (Array.isArray(currentAtom) !== Array.isArray(cand)) {
            throw new Error('Cannot change type of field')
          }

          if (Array.isArray(currentAtom)) {
            // TODO
          } else if (
            'value' in cand &&
            !diffFn(currentAtom.get(), cand.value)
          ) {
            currentAtom.set(cand.value)
          }
        }
      }

      return nodeRecord
    },
    toJSON() {
      const data: Record<string, Record<string, unknown>> = Object.create(null)

      for (const [gid, nodeRecord] of cacheMap.entries()) {
        data[gid] = Object.create(null)

        for (const [key, atom] of Object.entries(nodeRecord)) {
          data[gid][key] = atom.get()
        }
      }

      return data
    },
  }
}
