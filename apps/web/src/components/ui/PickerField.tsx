import { useState } from "react";
import { Icon } from "./Icon";

export type PickerOption = {
  value: string;
  label: string;
};

export function PickerField({
  label,
  value,
  options,
  placeholder = "Select an option",
  onChange,
  disabled = false,
}: {
  label?: string;
  value: string;
  options: PickerOption[];
  placeholder?: string;
  onChange: (value: string) => void;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const selected = options.find((option) => option.value === value);

  return (
    <div>
      {label && <p className="picker-label">{label}</p>}
      <button
        aria-label={label ?? placeholder}
        className="picker-field"
        disabled={disabled}
        onClick={() => setOpen(true)}
        type="button"
      >
        <span className={selected ? "text-ink" : "text-slate-400"}>
          {selected?.label ?? placeholder}
        </span>
        <Icon name="chevron-down" size={18} />
      </button>
      {open && (
        <div
          className="picker-backdrop"
          onClick={() => setOpen(false)}
          role="presentation"
        >
          <section
            aria-label={label ?? placeholder}
            aria-modal="true"
            className="picker-sheet"
            onClick={(event) => event.stopPropagation()}
            role="dialog"
          >
            <div className="picker-handle" />
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-base font-semibold text-ink">
                {label ?? placeholder}
              </h2>
              <button
                aria-label="Close picker"
                className="icon-button"
                onClick={() => setOpen(false)}
                type="button"
              >
                ×
              </button>
            </div>
            <div className="max-h-[52vh] overflow-y-auto">
              {options.map((option) => (
                <button
                  className="picker-option"
                  key={option.value}
                  onClick={() => {
                    onChange(option.value);
                    setOpen(false);
                  }}
                  type="button"
                >
                  <span>{option.label}</span>
                  {option.value === value && <Icon name="check" size={18} />}
                </button>
              ))}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
