import {WorkPackageResource} from './../../api/api-v3/hal-resources/work-package-resource.service';
import {DisplayField} from './../../wp-display/wp-display-field/wp-display-field.module';
import {WorkPackageDisplayFieldService} from './../../wp-display/wp-display-field/wp-display-field.service';
import {injectorBridge} from '../../angular/angular-injector-bridge.functions';
export const cellClassName = 'wp-table--cell-span';
export const cellEmptyPlaceholder = '-';

export class CellBuilder {

  public wpDisplayField:WorkPackageDisplayFieldService;

  constructor() {
    injectorBridge(this);
  }

  public build(workPackage:WorkPackageResource, name:string) {
    let fieldSchema = workPackage.schema[name];

    let td = document.createElement('td');
    let span = document.createElement('span');
    span.classList.add(cellClassName, name);
    const field = <DisplayField> this.wpDisplayField.getField(workPackage, name, fieldSchema);

    let text;

    if (fieldSchema.writable) {
      span.classList.add('-editable');
    }

    if (fieldSchema.required) {
      span.classList.add('-required');
    }

    if (field.isEmpty()) {
      span.classList.add('-placeholder');
      text = cellEmptyPlaceholder;
    } else {
      text = field.valueString;
      td.setAttribute('aria-label', `${field.label} ${text}`);
    }

    field.render(span, text);
    td.appendChild(span);

    return td;
  }
}

CellBuilder.$inject = ['wpDisplayField'];