"use client";

import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import {
  EXERCISE_LIBRARY,
  LibraryExercise,
  goalLabels,
  libraryExerciseToForm,
  muscleLabels,
} from "@/lib/exercise-library";

type ExercisePatch = {
  name: string;
  description?: string;
  sets?: string;
  reps?: string;
  duration?: string;
  variationNotes?: string;
  notes?: string;
};

export default function ExerciseNameField({
  value,
  onChange,
  onSelectLibrary,
  placeholder = "Digite ou escolha um exercício…",
}: {
  value: string;
  onChange: (name: string) => void;
  /** Ao escolher da lista, preenche o exercício completo. */
  onSelectLibrary: (patch: ExercisePatch) => void;
  placeholder?: string;
}) {
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState(0);
  const rootRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLUListElement>(null);

  const suggestions = useMemo(() => {
    const q = value.trim().toLowerCase();
    if (!q) {
      return EXERCISE_LIBRARY.slice(0, 12);
    }
    return EXERCISE_LIBRARY.filter(
      (e) =>
        e.name.toLowerCase().includes(q) ||
        muscleLabels[e.muscle].toLowerCase().includes(q) ||
        goalLabels[e.goal].toLowerCase().includes(q)
    ).slice(0, 14);
  }, [value]);

  useEffect(() => {
    setHighlight(0);
  }, [suggestions.length, value]);

  useEffect(() => {
    function onDocClick(e: MouseEvent) {
      if (!rootRef.current?.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  function applyLibrary(ex: LibraryExercise) {
    const form = libraryExerciseToForm(ex);
    onSelectLibrary({
      name: form.name,
      description: form.description,
      sets: form.sets,
      reps: form.reps,
      duration: form.duration,
      variationNotes: form.variationNotes,
      notes: form.notes,
    });
    setOpen(false);
  }

  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (!open && (e.key === "ArrowDown" || e.key === "Enter")) {
      setOpen(true);
      return;
    }
    if (!open) return;

    if (e.key === "ArrowDown") {
      e.preventDefault();
      setHighlight((h) => Math.min(h + 1, Math.max(suggestions.length - 1, 0)));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setHighlight((h) => Math.max(h - 1, 0));
    } else if (e.key === "Enter" && suggestions[highlight]) {
      e.preventDefault();
      applyLibrary(suggestions[highlight]);
    } else if (e.key === "Escape") {
      setOpen(false);
    }
  }

  useEffect(() => {
    const el = listRef.current?.children[highlight] as HTMLElement | undefined;
    el?.scrollIntoView({ block: "nearest" });
  }, [highlight]);

  return (
    <div ref={rootRef} className="relative mb-2">
      <input
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={onKeyDown}
        placeholder={placeholder}
        autoComplete="off"
        className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
        aria-autocomplete="list"
        aria-expanded={open}
      />
      <p className="mt-1 text-[10px] text-slate-500">
        Digite o nome livremente ou escolha da lista
      </p>

      {open && (
        <ul
          ref={listRef}
          className="absolute z-30 mt-1 max-h-56 w-full overflow-y-auto rounded-lg border border-slate-700 bg-slate-950 shadow-xl"
          role="listbox"
        >
          {suggestions.length === 0 ? (
            <li className="px-3 py-2 text-xs text-slate-500">
              Nenhum da biblioteca — o nome digitado será usado como está.
            </li>
          ) : (
            suggestions.map((ex, i) => (
              <li key={ex.id} role="option" aria-selected={i === highlight}>
                <button
                  type="button"
                  onMouseDown={(e) => e.preventDefault()}
                  onClick={() => applyLibrary(ex)}
                  onMouseEnter={() => setHighlight(i)}
                  className={`w-full px-3 py-2 text-left text-sm ${
                    i === highlight ? "bg-violet-900/60" : "hover:bg-slate-900"
                  }`}
                >
                  <span className="font-medium text-slate-100">{ex.name}</span>
                  <span className="mt-0.5 block text-[11px] text-violet-300">
                    {muscleLabels[ex.muscle]} · {goalLabels[ex.goal]} · {ex.sets}x
                    {ex.reps || ex.duration}
                  </span>
                </button>
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  );
}
