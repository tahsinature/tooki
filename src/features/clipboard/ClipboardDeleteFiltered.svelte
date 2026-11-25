<script lang="ts">
  import ConfirmationActions from '../../components/ConfirmationActions.svelte';
  import { request } from './api';
  let {
    plan,
    onclose,
    ondeleted,
  }: {
    plan: { token: number; count: number; query: string };
    onclose: () => void;
    ondeleted: (count: number) => void;
  } = $props();
  async function confirm() {
    const deleted = await request<number>('deleteFiltered', {
      token: plan.token,
    });
    ondeleted(deleted);
  }
</script>

<ConfirmationActions
  title={`Delete ${plan.count} filtered ${plan.count === 1 ? 'result' : 'results'}?`}
  description={`Permanently remove the matching unpinned items across all pages${plan.query.trim() ? ` for “${plan.query.trim()}”` : ''}. Pinned items stay. Tooki’s stored copies will be deleted; original files stay untouched.`}
  confirmLabel={`Delete ${plan.count} ${plan.count === 1 ? 'Result' : 'Results'}`}
  onconfirm={confirm}
  {onclose}
/>
