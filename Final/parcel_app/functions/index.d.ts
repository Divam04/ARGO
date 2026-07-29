import * as functions from 'firebase-functions';
export declare const importStudents: functions.https.CallableFunction<any, Promise<{
    success: boolean;
    message: string;
}>, unknown>;
export declare const sendEmail: any;
export declare const scanLabel: functions.https.CallableFunction<any, Promise<{
    success: boolean;
    data: any;
}>, unknown>;
export declare const assignRack: functions.https.CallableFunction<any, Promise<{
    success: boolean;
    rack: string;
}>, unknown>;
export declare const commitParcel: functions.https.CallableFunction<any, Promise<{
    success: boolean;
    parcelId: any;
    pin: string;
}>, unknown>;
//# sourceMappingURL=index.d.ts.map