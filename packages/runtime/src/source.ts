import type { DocumentNode, GraphQLError, OperationTypeNode } from 'graphql'
import type { AsyncIterableOrValue, PromiseOrValue } from './utils'

export interface Operation {
  query: DocumentNode
  variables?: Record<string, unknown>
  kind: OperationTypeNode
}

interface IncrementalChunkBase {
  label: string
  path: string[]
}

export interface IncrementalDeferChunk extends IncrementalChunkBase {
  data: Record<string, unknown>
}

export interface IncrementalStreamChunk extends IncrementalChunkBase {
  items: unknown[]
}

export type IncrementalChunk = IncrementalDeferChunk | IncrementalStreamChunk

export type SourceResultChunk = {
  data?: Record<string, unknown>
  incremental?: IncrementalChunk[]
  errors?: GraphQLError[]
  hasNext?: boolean
}

export type Source = (
  operation: Operation
) => PromiseOrValue<AsyncIterableOrValue<SourceResultChunk | Error> | null>
