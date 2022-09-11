import {
  DefinitionNode,
  DocumentNode,
  Kind,
  OperationDefinitionNode,
  parse,
} from 'graphql'
import type { Cache } from './cache'
import type { Source, SourceResultChunk } from './source'

export interface CreateClientOptions {
  cache: Cache
  sources: Source[]
}

const isOperationDefinition = (
  node: DefinitionNode
): node is OperationDefinitionNode => {
  return node.kind === Kind.OPERATION_DEFINITION
}

export const createClient = (options: CreateClientOptions) => {
  const cache = options.cache

  return {
    async query(
      query: string | DocumentNode,
      variables?: Record<string, unknown>
    ) {
      const queryDocument = typeof query === 'string' ? parse(query) : query

      const operation = queryDocument.definitions.find(isOperationDefinition)
      if (!operation) throw new Error('No operation found in query')

      const result = await (async () => {
        for (const source of options.sources) {
          try {
            const currResult = await source({
              kind: operation.operation,
              query: queryDocument,
              variables,
            })
            if (currResult) return currResult
          } catch (e) {
            if (e instanceof Error) return e
            else throw new Error('Value other than Error thrown from source')
          }
        }
      })()

      if (!result) {
        throw new Error('No appropriate source found to execute the query')
      }

      const handle = (chunk: SourceResultChunk | Error) => {
        if (chunk instanceof Error) throw chunk
        else if ('data' in chunk && chunk?.data) {
          cache.set(chunk.data, ['root'])
        }
        else if ('incremental' in chunk && chunk?.incremental) {
          for (const incrementalChunk of chunk.incremental) {
            // TODO
          }
        }
      }

      if (Symbol.asyncIterator in result) {
        const iter = result as AsyncIterable<SourceResultChunk | Error>
        for await (const chunk of iter) {
          handle(chunk)
        }
      }
      else handle(result as SourceResultChunk | Error)
    },
  }
}
