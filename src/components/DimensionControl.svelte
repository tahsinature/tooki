<script lang="ts">
  let {
    id,
    label,
    value,
    min,
    max,
    onchange,
  }: {
    id: string;
    label: string;
    value: number;
    min: number;
    max: number;
    onchange: (value: number) => void;
  } = $props();
  function update(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    if (!Number.isFinite(input.valueAsNumber)) return;
    onchange(Math.max(min, Math.min(max, Math.round(input.valueAsNumber))));
  }
</script>

<div class="dimension-control">
  <label for={id}>{label}</label>
  <input {id} type="range" {min} {max} step="1" {value} oninput={update} />
  <div class="dimension-value">
    <input
      type="number"
      aria-label={label + ' in pixels'}
      {min}
      {max}
      step="1"
      {value}
      onchange={update}
      onblur={(event) => {
        event.currentTarget.value = String(value);
      }}
    />
    <span aria-hidden="true">px</span>
  </div>
</div>

<style>
  .dimension-control {
    display: grid;
    grid-template-columns: 132px minmax(40px, 1fr) 62px;
    align-items: center;
    gap: 10px;
    font-size: 12px;
  }
  input[type='range'] {
    width: 100%;
    min-width: 0;
    margin: 0;
    accent-color: var(--accent);
  }
  .dimension-value {
    display: flex;
    align-items: center;
    border: 1px solid var(--line);
    border-radius: var(--radius-control);
    background: var(--surface);
    padding: 5px 6px;
    gap: 3px;
  }
  .dimension-value:focus-within {
    border-color: var(--input-focus-border);
  }
  input[type='number'] {
    width: 100%;
    min-width: 0;
    padding: 0;
    border: 0;
    background: transparent;
    color: var(--ink);
    font: inherit;
    font-variant-numeric: tabular-nums;
    appearance: textfield;
    text-align: right;
  }
  input::-webkit-inner-spin-button,
  input::-webkit-outer-spin-button {
    appearance: none;
    margin: 0;
  }
  span {
    color: var(--muted);
    font-size: 10px;
  }
  @media (max-width: 420px) {
    .dimension-control {
      grid-template-columns: 112px minmax(30px, 1fr) 56px;
      gap: 6px;
    }
  }
</style>
