import ComposableArchitecture
import Foundation
import TookiKit

extension ShelfImageConversionFeature {
    func prepare(items: [ShelfConversionItem], options: ImageConversionOptions) -> Effect<Action> {
        .run { [client, uuid] send in
            do { try await client.validate(items) }
            catch {
                guard !Task.isCancelled else { return }
                await send(.validationFailed(error.localizedDescription))
                return
            }
            for item in items {
                guard !Task.isCancelled else { return }
                do {
                    let preview = try await client.prepare(item, options)
                    guard !Task.isCancelled else { await client.discard(preview); return }
                    let details: ImagePreviewDetails
                    do { details = try await client.details(preview) }
                    catch { await client.discard(preview); throw error }
                    guard !Task.isCancelled else { await client.discard(preview); return }
                    await send(.prepared(ShelfConversionResult(id: uuid(), item: item, preview: preview,
                                                               details: details, revision: uuid())))
                    // Cancellation can race with delivery to the main actor; discard is idempotent.
                    if Task.isCancelled { await client.discard(preview); return }
                } catch {
                    guard !Task.isCancelled else { return }
                    await send(.preparationFailed(item.id, "\(item.name): \(error.localizedDescription)"))
                }
            }
            await send(.preparationFinished)
        }.cancellable(id: CancelID.preparation, cancelInFlight: true)
    }

    func save(results: [ShelfConversionResult], output: ImageConversionOptions.Output) -> Effect<Action> {
        // Saving is deliberately non-cancellable: each native commit updates the file and shelf row together.
        .run { [client] send in
            var sources: Set<UUID> = []
            var rows: [UUID] = []
            for result in results {
                do {
                    let row = try await client.save(result, output)
                    rows.append(row)
                    sources.insert(result.item.id)
                    if !result.wasOpened { await client.discard(result.preview) }
                    await send(.saved(source: result.item.id, row: row))
                } catch {
                    await send(.saveFailed("\(result.item.name): \(error.localizedDescription)"))
                }
            }
            await send(.saveFinished(sources: sources, rows: rows))
        }
    }

    func refresh(results: [ShelfConversionResult], id: UUID) -> Effect<Action> {
        .run { [client] send in
            for result in results {
                guard !Task.isCancelled else { return }
                do {
                    let details = try await client.details(result.preview)
                    guard !Task.isCancelled else { return }
                    await send(.detailsLoaded(refresh: id, result: result.id, details))
                } catch {
                    guard !Task.isCancelled else { return }
                    await send(.detailsFailed(refresh: id, result: result.id, error.localizedDescription))
                }
            }
            await send(.refreshFinished(id))
        }.cancellable(id: CancelID.refresh, cancelInFlight: true)
    }
}
